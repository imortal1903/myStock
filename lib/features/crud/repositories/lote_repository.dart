import 'package:sqflite/sqflite.dart';
import '../../../core/database/db.dart';
import '../models/lote.dart';
import '../models/lote_com_produto.dart';
import '../models/estoque_resumo.dart';
import '../models/movimentacao_estoque.dart';
import '../../../core/extensions/sqldate_extension.dart';
import 'movimentacao_repository.dart';

class LoteRepository {
  final Db _db;
  final MovimentacaoRepository _movRepo;
  LoteRepository({Db? db, MovimentacaoRepository? movRepo})
      : _db = db ?? Db.instance,
        _movRepo = movRepo ?? MovimentacaoRepository();

  Future<int> insert(Lote lote) async {
    final db = await _db.database;
    return db.insert('lotes_produto', lote.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> update(Lote lote) async {
    final db = await _db.database;
    return db.update('lotes_produto', lote.toMap(),
        where: 'id = ?', whereArgs: [lote.id]);
  }


  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('lotes_produto', where: 'id = ?', whereArgs: [id]);
  }

  /// Por padrão, não traz lotes desativados (soft-deleted) - mesmo
  /// critério usado em `ProdutoRepository.search(apenasAtivos: true)`.
  Future<List<Lote>> getByProduto(
      int produtoId, {
        bool incluirDesativados = false,
      }) async {
    final db   = await _db.database;
    final rows = await db.query(
      'lotes_produto',
      where: incluirDesativados
          ? 'produto_id = ?'
          : 'produto_id = ? AND ativo = 1',
      whereArgs: [produtoId],
      orderBy: 'data_validade ASC',
    );
    return rows.map(Lote.fromMap).toList();
  }

  Future<List<Lote>> getLotesProximosVencimento(int dias) async {
    final db     = await _db.database;
    final limite = DateTime.now()
        .add(Duration(days: dias))
        .toSqlDate;

    final rows = await db.rawQuery('''
      SELECT * FROM lotes_produto
      WHERE status = 'ATIVO'
        AND ativo = 1
        AND data_validade <= ?
      ORDER BY data_validade ASC
    ''', [limite]);

    return rows.map(Lote.fromMap).toList();
  }

  Future<List<LoteComProduto>> getLotesProximosVencimentoComProduto(
      int dias) async {
    final db     = await _db.database;
    final limite = DateTime.now()
        .add(Duration(days: dias))
        .toSqlDate;

    final rows = await db.rawQuery('''
      SELECT lp.*, p.nome AS produto_nome, p.unidade AS produto_unidade
      FROM lotes_produto lp
      JOIN produtos p ON p.id = lp.produto_id
      WHERE lp.status = 'ATIVO'
        AND lp.ativo = 1
        AND lp.data_validade <= ?
      ORDER BY lp.data_validade ASC
    ''', [limite]);

    return rows.map(LoteComProduto.fromMap).toList();
  }

  Future<void> atualizarStatusVencidos() async {
    final db = await _db.database;
    final hoje = DateTime.now().toSqlDate;

    // Antes de promover os lotes a VENCIDO, registra a perda de cada um -
    // é esse registro em movimentacoes_estoque (motivo VENCIMENTO) que
    // alimenta os cards "Vencidas" e "Para onde o estoque está indo" na
    // tela de Análise. Sem ele, o status muda no banco, mas a Análise
    // nunca "enxerga" a perda.
    final expirando = await db.query(
      'lotes_produto',
      columns: ['id', 'quantidade'],
      where: "status = 'ATIVO' AND ativo = 1 AND data_validade < ?",
      whereArgs: [hoje],
    );

    for (final row in expirando) {
      final quantidade = row['quantidade'] as double;
      if (quantidade <= 0) continue;
      await _movRepo.insert(MovimentacaoEstoque(
        loteId: row['id'] as int,
        tipo: TipoMovimentacao.perda,
        motivo: MotivoMovimentacao.vencimento,
        quantidade: quantidade,
        observacao: 'Baixa automática por vencimento do lote',
        criadoEm: DateTime.now(),
      ));
    }

    await db.rawUpdate('''
      UPDATE lotes_produto
      SET status = 'VENCIDO'
      WHERE status = 'ATIVO'
        AND ativo = 1
        AND data_validade < ?
    ''', [hoje]);

    // Reverte lotes cuja validade foi editada para uma data futura depois
    // de já terem sido marcados como vencidos.
    await db.rawUpdate('''
      UPDATE lotes_produto
      SET status = 'ATIVO'
      WHERE status = 'VENCIDO'
        AND ativo = 1
        AND data_validade >= ?
    ''', [hoje]);
  }


  Future<Lote?> getById(int id) async {
    final db   = await _db.database;
    final rows = await db.query('lotes_produto',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Lote.fromMap(rows.first);
  }

  Future<Map<int, EstoqueResumo>> getResumoEstoquePorProduto() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        produto_id,
        SUM(CASE WHEN status = 'ATIVO' AND ativo = 1 THEN quantidade ELSE 0 END) AS qtd_ativa,
        MAX(CASE WHEN status = 'VENCIDO' AND ativo = 1 THEN 1 ELSE 0 END)        AS tem_vencido
      FROM lotes_produto
      GROUP BY produto_id
    ''');

    return {
      for (final r in rows)
        r['produto_id'] as int: EstoqueResumo(
          quantidadeAtiva: (r['qtd_ativa'] as num).toDouble(),
          temLoteVencido: (r['tem_vencido'] as int) == 1,
        ),
    };
  }

  /// Exclusão lógica (soft delete) de um lote: marca `ativo = 0` em vez de
  /// apagar a linha. Diferente de [delete] (hard delete), isso nunca
  /// esbarra na constraint de chave estrangeira de `venda_itens.lote_id`
  /// (que não tem `ON DELETE CASCADE`).
  Future<void> desativar(int id) async {
    final db = await _db.database;
    await db.update(
      'lotes_produto',
      {'ativo': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> registrarPerda({
    required int loteId,
    required double quantidade,
    required MotivoMovimentacao motivo,
    String? observacao,
  }) async {
    if (quantidade <= 0) {
      throw ArgumentError('A quantidade da perda precisa ser maior que zero.');
    }

    final lote = await getById(loteId);
    if (lote == null) {
      throw ArgumentError('Lote $loteId não encontrado.');
    }

    // Nunca registra mais do que o lote realmente tem.
    final perda = quantidade > lote.quantidade ? lote.quantidade : quantidade;

    await _movRepo.insert(MovimentacaoEstoque(
      loteId: loteId,
      tipo: TipoMovimentacao.perda,
      motivo: motivo,
      quantidade: perda,
      observacao: observacao,
      criadoEm: DateTime.now(),
    ));

    final restante = lote.quantidade - perda;
    final novoStatus = restante <= 0 && lote.status == LoteStatus.ativo
        ? LoteStatus.esgotado
        : lote.status;

    await update(lote.copyWith(
      quantidade: restante < 0 ? 0 : restante,
      status: novoStatus,
    ));
  }
}