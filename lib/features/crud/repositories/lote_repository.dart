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

  // ── INSERT ─────────────────────────────────────────────────────────────────

  Future<int> insert(Lote lote) async {
    final db = await _db.database;
    return db.insert('lotes_produto', lote.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────

  Future<int> update(Lote lote) async {
    final db = await _db.database;
    return db.update('lotes_produto', lote.toMap(),
        where: 'id = ?', whereArgs: [lote.id]);
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('lotes_produto', where: 'id = ?', whereArgs: [id]);
  }

  // ── GET BY PRODUTO ─────────────────────────────────────────────────────────

  Future<List<Lote>> getByProduto(int produtoId) async {
    final db   = await _db.database;
    final rows = await db.query(
      'lotes_produto',
      where:   'produto_id = ?',
      whereArgs: [produtoId],
      orderBy: 'data_validade ASC',
    );
    return rows.map(Lote.fromMap).toList();
  }

  // ── LOTES PRÓXIMOS AO VENCIMENTO ───────────────────────────────────────────

  Future<List<Lote>> getLotesProximosVencimento(int dias) async {
    final db     = await _db.database;
    final limite = DateTime.now()
        .add(Duration(days: dias))
        .toSqlDate;

    final rows = await db.rawQuery('''
      SELECT * FROM lotes_produto
      WHERE status = 'ATIVO'
        AND data_validade <= ?
      ORDER BY data_validade ASC
    ''', [limite]);

    return rows.map(Lote.fromMap).toList();
  }

  // ── LOTES PRÓXIMOS AO VENCIMENTO (COM DADOS DO PRODUTO) ────────────────────

  /// Igual a [getLotesProximosVencimento], mas já traz nome e unidade do
  /// produto de cada lote — para telas que listam lotes de vários produtos
  /// ao mesmo tempo (ex.: seção Atenção do dashboard de Análise) e
  /// precisam dizer qual produto é cada um sem uma consulta extra por
  /// lote.
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
        AND lp.data_validade <= ?
      ORDER BY lp.data_validade ASC
    ''', [limite]);

    return rows.map(LoteComProduto.fromMap).toList();
  }

  // ── ATUALIZA STATUS ────────────────────────────────────────────────────────

  Future<void> atualizarStatusVencidos() async {
    final db = await _db.database;
    final hoje = DateTime.now().toSqlDate;

    // Antes de promover os lotes a VENCIDO, registra a perda de cada um —
    // é esse registro em movimentacoes_estoque (motivo VENCIMENTO) que
    // alimenta os cards "Vencidas" e "Para onde o estoque está indo" na
    // tela de Análise. Sem ele, o status muda no banco, mas a Análise
    // nunca "enxerga" a perda.
    //
    // Filtra por status = 'ATIVO' também aqui, então um lote já VENCIDO
    // não é registrado de novo em execuções seguintes (idempotente).
    final expirando = await db.query(
      'lotes_produto',
      columns: ['id', 'quantidade'],
      where: "status = 'ATIVO' AND data_validade < ?",
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
        AND data_validade < ?
    ''', [hoje]);

    // Reverte lotes cuja validade foi editada para uma data futura depois
    // de já terem sido marcados como vencidos. Caso raro (edição manual),
    // e propositalmente não estorna a movimentação de perda já registrada
    // acima — isso ficaria como um ajuste manual do usuário, se necessário.
    await db.rawUpdate('''
      UPDATE lotes_produto
      SET status = 'ATIVO'
      WHERE status = 'VENCIDO'
        AND data_validade >= ?
    ''', [hoje]);
  }

  // ── GET BY ID ──────────────────────────────────────────────────────────────

  Future<Lote?> getById(int id) async {
    final db   = await _db.database;
    final rows = await db.query('lotes_produto',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Lote.fromMap(rows.first);
  }

  // ── RESUMO DE ESTOQUE POR PRODUTO ──────────────────────────────────────────

  Future<Map<int, EstoqueResumo>> getResumoEstoquePorProduto() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        produto_id,
        SUM(CASE WHEN status = 'ATIVO'   THEN quantidade ELSE 0 END) AS qtd_ativa,
        MAX(CASE WHEN status = 'VENCIDO' THEN 1 ELSE 0 END)          AS tem_vencido
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
}