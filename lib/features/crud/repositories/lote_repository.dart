import 'package:sqflite/sqflite.dart';
import '../../../core/database/db.dart';
import '../models/lote.dart';
import '../models/estoque_resumo.dart';
import '../../../core/extensions/sqldate_extension.dart';

class LoteRepository {
  final Db _db;
  LoteRepository({Db? db}) : _db = db ?? Db.instance;

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
  // Retorna lotes com status ATIVO cuja data_validade <= hoje + [dias] dias.

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

  // ── ATUALIZA STATUS ────────────────────────────────────────────────────────

  Future<void> atualizarStatusVencidos() async {
    final db = await _db.database;
    final hoje = DateTime.now().toSqlDate;

    await db.rawUpdate('''
      UPDATE lotes_produto
      SET status = 'VENCIDO'
      WHERE status = 'ATIVO'
        AND data_validade < ?
    ''', [hoje]);

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
          quantidadeAtiva: (r['qtd_ativa'] as num).toInt(),
          temLoteVencido: (r['tem_vencido'] as int) == 1,
        ),
    };
  }
}