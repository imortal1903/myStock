import 'package:sqflite/sqflite.dart';
import '../../../core/database/db.dart';
import '../models/produto.dart';

class ProdutoRepository {
  final DatabaseHelper _db;
  ProdutoRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  // ── INSERT ─────────────────────────────────────────────────────────────────

  Future<int> insert(Produto p) async {
    final db = await _db.database;
    return db.insert('produtos', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────

  Future<int> update(Produto p) async {
    final db = await _db.database;
    return db.update('produtos', p.toMap(),
        where: 'id = ?', whereArgs: [p.id]);
  }

  // ── DELETE (soft) ──────────────────────────────────────────────────────────

  Future<int> deactivate(int id) async {
    final db = await _db.database;
    return db.update('produtos', {'ativo': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── DELETE (hard) ──────────────────────────────────────────────────────────

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('produtos', where: 'id = ?', whereArgs: [id]);
  }

  // ── SEARCH ─────────────────────────────────────────────────────────────────

  Future<List<Produto>> search(String query, {bool apenasAtivos = true}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> rows;

    if (query.trim().isEmpty) {
      rows = await db.query(
        'produtos',
        where: apenasAtivos ? 'ativo = 1' : null,
        orderBy: 'criado_em DESC',
      );
    } else {
      final pattern = '%${query.trim()}%';
      final whereAtivo = apenasAtivos ? 'AND ativo = 1' : '';
      rows = await db.rawQuery('''
        SELECT * FROM produtos
        WHERE (nome LIKE ? OR descricao LIKE ? OR codigo_barras LIKE ?)
        $whereAtivo
        ORDER BY criado_em DESC
      ''', [pattern, pattern, pattern]);
    }

    return rows.map(Produto.fromMap).toList();
  }

  // ── GET BY ID ──────────────────────────────────────────────────────────────

  Future<Produto?> getById(int id) async {
    final db   = await _db.database;
    final rows = await db.query('produtos',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Produto.fromMap(rows.first);
  }
}