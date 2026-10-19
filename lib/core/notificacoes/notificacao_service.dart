import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../core/extensions/date_extensions.dart';

import '../../features/crud/models/lote.dart';
import 'notificacao_config.dart';
import 'notificacao_navigation.dart';

/// Chamado quando o usuário toca em uma notificação com o app em segundo
/// plano/finalizado. Não há acesso à UI neste isolate — o toque real é
/// tratado depois, via [NotificacaoService.checkLaunchPayload] ou pelo
/// callback normal quando o app já está em primeiro plano.
@pragma('vm:entry-point')
void notificacaoBackgroundHandler(NotificationResponse response) {}

class NotificacaoService {
  NotificacaoService._();
  static final NotificacaoService instance = NotificacaoService._();

  final _plugin      = FlutterLocalNotificationsPlugin();
  bool  _initialized = false;

  static const _channelId   = 'estoque_validade';
  static const _channelName = 'Validade de Produtos';
  static const _channelDesc = 'Alertas de lotes próximos ao vencimento';

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (_) {}

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        NotificacaoNavigation.handlePayload(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificacaoBackgroundHandler,
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

  /// Chame isso uma vez, logo depois do `runApp`, para tratar o caso em que
  /// o app estava fechado e foi aberto por um toque em notificação.
  Future<void> checkLaunchPayload() async {
    await _ensureInit();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      await NotificacaoNavigation.handlePayload(
        details?.notificationResponse?.payload,
      );
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> requestPermission() async {
    await _ensureInit();
    final ok = await _android?.requestNotificationsPermission();
    return ok ?? false;
  }

  /// Garante permissão de alarme exato. Retorna `true` em
  /// plataformas que não exigem essa permissão.
  Future<bool> ensureExactAlarmPermission() async {
    await _ensureInit();
    final android = _android;
    if (android == null) return true;

    if (await android.canScheduleExactNotifications() ?? true) return true;

    await android.requestExactAlarmsPermission();
    return await android.canScheduleExactNotifications() ?? false;
  }

  Future<bool> requestAllPermissions() async {
    await requestPermission();
    return ensureExactAlarmPermission();
  }

  Future<void> scheduleForAllLotes(
      List<Lote> lotes,
      Map<int, String> nomes,
      NotificacaoConfig config,
      ) async {
    await cancelAll();

    if (!config.ativado) return;

    final now = DateTime.now();

    final porProduto = <int, List<Lote>>{};
    for (final lote in lotes) {
      if (lote.estaVencido) continue;
      porProduto.putIfAbsent(lote.produtoId, () => []).add(lote);
    }

    for (final entry in porProduto.entries) {
      final produtoId      = entry.key;
      final lotesDoProduto = entry.value;
      final nomeProduto    = nomes[produtoId] ?? 'Produto';
      final groupKey       = _groupKey(produtoId);

      final linhasResumo   = <String>[];
      DateTime? primeiraData;

      for (final lote in lotesDoProduto) {
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
            groupKey: groupKey,
            produtoId: produtoId,
          );

          primeiraData ??= dataAtual;

          dataAtual = dataAtual.add(
            Duration(hours: config.intervaloHoras),
          );

          idx++;
        }

        linhasResumo.add(
          'Lote $loteLabel vence em ${lote.validadeFormatada}',
        );
      }

      if (primeiraData != null) {
        await _zonedScheduleResumo(
          id: _buildSummaryId(produtoId),
          nomeProduto: nomeProduto,
          linhas: linhasResumo,
          groupKey: groupKey,
          produtoId: produtoId,
          when: primeiraData,
        );
      }
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> showTest() => _plugin.show(
    id: 0,
    title: '🔔 Notificações ativas',
    body: 'Você receberá alertas de validade de lotes conforme configurado.',
    notificationDetails: _details(),
  );

  int    _buildId(int loteId, int idx) => (loteId.abs() % 100000) + idx * 100000;
  int _buildSummaryId(int produtoId) => 900000000 + (produtoId.abs() % 90000000);
  String _groupKey(int produtoId) => 'produto_$produtoId';

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

  NotificationDetails _details({
    String? groupKey,
    bool isSummary = false,
    StyleInformation? styleInformation,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority:   Priority.high,
      icon:       '@mipmap/ic_launcher',
      groupKey: groupKey,
      setAsGroupSummary: isSummary,
      styleInformation: styleInformation,
    ),
  );

  Future<void> _zonedSchedule({
    required int      id,
    required String   titulo,
    required String   corpo,
    required DateTime when,
    String? groupKey,
    int?    produtoId,
  }) async {
    await _ensureInit();
    await _plugin.zonedSchedule(
      id: id,
      title: titulo,
      body: corpo,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details(groupKey: groupKey),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: produtoId != null ? _payload(produtoId) : null,
    );
  }

  Future<void> _zonedScheduleResumo({
    required int          id,
    required String       nomeProduto,
    required List<String> linhas,
    required String       groupKey,
    required int          produtoId,
    required DateTime     when,
  }) async {
    await _ensureInit();

    final titulo = linhas.length == 1
        ? '📦 $nomeProduto'
        : '📦 $nomeProduto - ${linhas.length} lotes por vencer';

    await _plugin.zonedSchedule(
      id: id,
      title: titulo,
      body: linhas.first,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details(
        groupKey: groupKey,
        isSummary: true,
        styleInformation: InboxStyleInformation(
          linhas,
          contentTitle: titulo,
          summaryText: nomeProduto,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: _payload(produtoId),
    );
  }

  String _payload(int produtoId) => 'produto:$produtoId';

  Future<void> _ensureInit() async {
    if(!_initialized)await init();
  }
}