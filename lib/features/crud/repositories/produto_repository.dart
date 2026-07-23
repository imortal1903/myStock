import 'package:sqflite/sqflite.dart';
import '../../../core/database/db.dart';
import '../models/produto.dart';

/// Lançada ao tentar salvar um produto com um código de barras que já
/// pertence a outro produto cadastrado.
class CodigoBarrasDuplicadoException implements Exception {
  final String codigoBarras;
  CodigoBarrasDuplicadoException(this.codigoBarras);

  @override
  String toString() =>
      'Já existe um produto cadastrado com o código de barras "$codigoBarras".';
}

class ProdutoRepository {
  final Db _db;
  ProdutoRepository({Db? db}) : _db = db ?? Db.instance;

  // ── Verificação de duplicidade ───────────────────────────────────────────────

  Future<bool> existsCodigoBarras(String codigoBarras, {int? excludeId}) async {
    final db = await _db.database;
    final where = excludeId != null ? 'codigo_barras = ? AND id != ?' : 'codigo_barras = ?';
    final args  = excludeId != null ? [codigoBarras, excludeId] : [codigoBarras];

    final rows = await db.query('produtos', where: where, whereArgs: args, limit: 1);
    return rows.isNotEmpty;
  }

  // ── INSERT ─────────────────────────────────────────────────────────────────

  Future<int> insert(Produto p) async {
    final codigo = p.codigoBarras?.trim();
    if (codigo != null && codigo.isNotEmpty) {
      if (await existsCodigoBarras(codigo)) {
        throw CodigoBarrasDuplicadoException(codigo);
      }
    }

    final db = await _db.database;
    return db.insert('produtos', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────

  Future<int> update(Produto p) async {
    final codigo = p.codigoBarras?.trim();
    if (codigo != null && codigo.isNotEmpty) {
      if (await existsCodigoBarras(codigo, excludeId: p.id)) {
        throw CodigoBarrasDuplicadoException(codigo);
      }
    }

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