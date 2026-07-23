import 'package:sqflite/sqflite.dart';
import '../../../core/database/db.dart';
import '../models/categoria.dart';

class CategoriaRepository {
  final Db _db;
  CategoriaRepository({Db? db}) : _db = db ?? Db.instance;

  Future<List<Categoria>> getAll() async {
    final db   = await _db.database;
    final rows = await db.query('categorias', orderBy: 'nome ASC');
    return rows.map(Categoria.fromMap).toList();
  }

  Future<Categoria?> getById(int id) async {
    final db   = await _db.database;
    final rows = await db.query('categorias', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Categoria.fromMap(rows.first);
  }

  Future<int> insert(Categoria c) async {
    final db = await _db.database;
    return db.insert('categorias', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> update(Categoria c) async {
    final db = await _db.database;
    return db.update('categorias', c.toMap(),
        where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('categorias', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> detachInactiveProducts(int categoriaId) async {
    final db = await _db.database;

    await db.update(
      'produtos',
      {'categoria_id': null},
      where: 'categoria_id = ? AND ativo = 0',
      whereArgs: [categoriaId],
    );
  }
}