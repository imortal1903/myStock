import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../core/extensions/date_extensions.dart';

import '../../features/crud/models/lote.dart';
import 'notification_config.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin      = FlutterLocalNotificationsPlugin();
  bool  _initialized = false;

  static const _channelId   = 'estoque_validade';
  static const _channelName = 'Validade de Produtos';
  static const _channelDesc = 'Alertas de lotes próximos ao vencimento';

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (_) {}

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  // ── Permissão ──────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    final ok = await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    return ok ?? false;
  }

  // ── Agendamento por LOTES ─────────────────────────────────────────────────
  /// Cancela tudo e reagenda com base nos lotes e na configuração.
  /// [nomes] mapeia produto_id → nome do produto.
  Future<void> scheduleForAllLotes(
      List<Lote> lotes,
      Map<int, String> nomes,
      NotificationConfig config,
      ) async {
    await cancelAll();

    if (!config.ativado) return;

    final now = DateTime.now();

    for (final lote in lotes) {
      if (lote.estaVencido) continue;

      final nomeProduto = nomes[lote.produtoId] ?? 'Produto';
      final loteLabel = lote.numeroLote ?? '#${lote.id}';

      var dataAtual = _withTime(
        lote.dataValidade.subtract(Duration(days: config.diasAntes)),
        config.hora,
        config.minuto,
      );

      while (dataAtual.isBefore(now)) {
        dataAtual = dataAtual.add(
          Duration(hours: config.intervaloHoras),
        );
      }

      final limite = _withTime(
        lote.dataValidade,
        23,
        59,
      );

      int idx = 0;

      while (!dataAtual.isAfter(limite) && idx < 20) {
        final dias = lote.dataValidade.differenceInDays(dataAtual);

        await _zonedSchedule(
          id: _buildId(lote.id!, idx),
          titulo: _titulo(dias, nomeProduto),
          corpo: _corpo(
            dias,
            loteLabel,
            lote.validadeFormatada,
          ),
          when: dataAtual,
        );

        dataAtual = dataAtual.add(
          Duration(hours: config.intervaloHoras),
        );

        idx++;
      }
    }
  }

  // ── Cancelamento ──────────────────────────────────────────────────────────

  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Teste imediato ────────────────────────────────────────────────────────

  Future<void> showTest() => _plugin.show(
    0,
    '🔔 Notificações ativas',
    'Você receberá alertas de validade de lotes conforme configurado.',
    _details(),
  );

  // ── Helpers ───────────────────────────────────────────────────────────────

  int    _buildId(int loteId, int idx) => (loteId.abs() % 100000) + idx * 100000;

  String _titulo(int dias, String nome) {
    if (dias <= 0) return '⚠️ Lote de $nome vence hoje!';
    if (dias == 1) return '⚠️ Lote de $nome vence amanhã!';
    return '📦 Lote de $nome vence em $dias dias';
  }

  String _corpo(int dias, String lote, String validade) => dias <= 1
      ? 'Lote $lote vence em $validade. Verifique o estoque.'
      : 'Lote $lote vence em $validade. Tome uma ação a tempo.';

  DateTime _withTime(DateTime d, int h, int m) =>
      DateTime(d.year, d.month, d.day, h, m);

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority:   Priority.high,
      icon:       '@mipmap/ic_launcher',
    ),
  );

  Future<void> _zonedSchedule({
    required int      id,
    required String   titulo,
    required String   corpo,
    required DateTime when,
  }) async {
    await _ensureInit();
    await _plugin.zonedSchedule(
      id, titulo, corpo,
      tz.TZDateTime.from(when, tz.local),
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _ensureInit() async {
    if(!_initialized)await init();
  }
}