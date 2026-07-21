import 'package:sqflite/sqflite.dart';
import '../../../core/database/db.dart';
import '../models/produto.dart';

class ProdutoRepository {
  final Db _db;
  ProdutoRepository({Db? db}) : _db = db ?? Db.instance;

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
  // Busca por texto (nome / descrição / código de barras) com filtro
  // opcional por categoria. categoriaId == null → não filtra por categoria.

  Future<List<Produto>> search(
      String query, {
        bool apenasAtivos = true,
        int? categoriaId,
      }) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> rows;

    final conditions = <String>[];
    final args = <Object?>[];

    if (apenasAtivos) {
      conditions.add('ativo = 1');
    }
    if (categoriaId != null) {
      conditions.add('categoria_id = ?');
      args.add(categoriaId);
    }

    if (query.trim().isEmpty) {
      rows = await db.query(
        'produtos',
        where: conditions.isEmpty ? null : conditions.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'criado_em DESC',
      );
    } else {
      final pattern = '%${query.trim()}%';
      conditions.add('(nome LIKE ? OR descricao LIKE ? OR codigo_barras LIKE ?)');
      final searchArgs = [...args, pattern, pattern, pattern];

      rows = await db.rawQuery('''
        SELECT * FROM produtos
        WHERE ${conditions.join(' AND ')}
        ORDER BY criado_em DESC
      ''', searchArgs);
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