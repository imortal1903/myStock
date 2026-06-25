import 'package:sqflite/sqflite.dart';
import '../../../core/database/db.dart';
import '../models/notificacao.dart';
import '../../../core/notifications/notification_config.dart';

class NotificacaoRepository {
  final DatabaseHelper _db;
  NotificacaoRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  Future<int> insert(Notificacao n) async {
    final db = await _db.database;
    return db.insert('notificacoes', n.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAutomaticas() async {
    final db = await _db.database;

    await db.delete(
      'notificacoes',
      where: 'tipo IN (?, ?)',
      whereArgs: [
        NotificacaoTipo.validadeProxima.name,
        NotificacaoTipo.produtoVencido.name,
      ],
    );
  }

  Future<bool> existe({
    required int loteId,
    required NotificacaoTipo tipo,
  }) async {
    final db = await _db.database;

    final r = await db.query(
      'notificacoes',
      where: 'lote_id = ? AND tipo = ?',
      whereArgs: [
        loteId,
        tipo.name,
      ],
      limit: 1,
    );

    return r.isNotEmpty;
  }

  Future<List<Notificacao>> getNaoVisualizadas() async {
    final db   = await _db.database;
    final rows = await db.query('notificacoes',
        where: 'visualizada = 0', orderBy: 'criado_em DESC');
    return rows.map(Notificacao.fromMap).toList();
  }

  Future<List<Notificacao>> getAll() async {
    final db   = await _db.database;
    final rows = await db.query('notificacoes', orderBy: 'criado_em DESC');
    return rows.map(Notificacao.fromMap).toList();
  }

  Future<void> marcarComoVisualizada(int id) async {
    final db = await _db.database;
    await db.update('notificacoes', {'visualizada': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> marcarTodasComoVisualizadas() async {
    final db = await _db.database;
    await db.update('notificacoes', {'visualizada': 1});
  }

  Future<int> countNaoVisualizadas() async {
    final db  = await _db.database;
    final res = await db.rawQuery(
        'SELECT COUNT(*) as c FROM notificacoes WHERE visualizada = 0');
    return (res.first['c'] as int? ?? 0);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('notificacoes', where: 'id = ?', whereArgs: [id]);
  }

  Future<NotificationConfig> load() async {
    final db = await _db.database;

    final rows = await db.query(
      'notification_config',
      limit: 1,
    );

    if (rows.isEmpty) {
      return const NotificationConfig();
    }

    final map = rows.first;

    return NotificationConfig(
      ativado: (map['ativado'] as int) == 1,
      diasAntes: map['diasAntes'] as int,
      hora: map['hora'] as int,
      minuto: map['minuto'] as int,
      intervaloHoras: map['intervaloHoras'] as int,
    );
  }

  Future<void> save(NotificationConfig config) async {
    final db = await _db.database;

    await db.insert(
      'notification_config',
      {
        'id': 1,
        'ativado': config.ativado ? 1 : 0,
        'diasAntes': config.diasAntes,
        'hora': config.hora,
        'minuto': config.minuto,
        'intervaloHoras': config.intervaloHoras,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}