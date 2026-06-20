import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/notifications/notification_config.dart';
import '../../../core/notifications/notification_service.dart';

import '../repositories/lote_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/produto_repository.dart';

enum NotifSaveStatus { idle, saving, saved, error }

class NotificationViewModel extends ChangeNotifier {
  final NotificacaoRepository _notifRepo;
  final ProdutoRepository _produtoRepo;
  final LoteRepository _loteRepo;

  NotificationViewModel({
    NotificacaoRepository? notifRepo,
    ProdutoRepository? produtoRepo,
    LoteRepository? loteRepo,
  })  : _notifRepo = notifRepo ?? NotificacaoRepository(),
        _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo = loteRepo ?? LoteRepository() {
    _load();
  }

  // ───────────────── STATE ─────────────────

  NotificationConfig _config = const NotificationConfig();
  NotifSaveStatus _status = NotifSaveStatus.idle;
  bool _loading = true;
  String? _error;

  // ───────────────── GETTERS ─────────────────

  NotificationConfig get config => _config;
  NotifSaveStatus get status => _status;
  bool get loading => _loading;
  String? get error => _error;
  bool get isSaving => _status == NotifSaveStatus.saving;

  // ───────────────── LOAD ─────────────────

  Future<void> _load() async {
    _loading = true;
    notifyListeners();

    try {
      _config = await _notifRepo.load();
    } catch (e) {
      _error = 'Erro ao carregar configurações: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ───────────────── UPDATE CONFIG ─────────────────

  void setAtivado(bool v) {
    _config = _config.copyWith(ativado: v);
    notifyListeners();
  }

  void setDiasAntes(int v) {
    _config = _config.copyWith(diasAntes: v);
    notifyListeners();
  }

  void setHorario(int hora, int minuto) {
    _config = _config.copyWith(
      hora: hora,
      minuto: minuto,
    );

    notifyListeners();
  }

  void setIntervalo(int horas) {
    _config = _config.copyWith(
      intervaloHoras: horas,
    );

    notifyListeners();
  }

  // ───────────────── PERMISSIONS ─────────────────

  Future<bool> _requestAllPermissions() async {
    await NotificationService.instance.requestPermission();

    if (!kIsWeb && Platform.isAndroid) {
      final android = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        final canSchedule =
        await android.canScheduleExactNotifications();

        if (canSchedule == false) {
          await android.requestExactAlarmsPermission();

          final granted =
          await android.canScheduleExactNotifications();

          if (granted == false) {
            return false;
          }
        }
      }
    }

    return true;
  }

  // ───────────────── SAVE ─────────────────

  Future<void> salvar() async {
    _status = NotifSaveStatus.saving;
    _error = null;

    notifyListeners();

    try {
      final granted = await _requestAllPermissions();

      if (!granted) {
        _status = NotifSaveStatus.error;

        _error =
        'Permissão de alarme exato negada. '
            'Ative em Configurações → Aplicativos → Alarmes e lembretes.';

        notifyListeners();
        return;
      }

      // salva config
      await _notifRepo.save(_config);

      // busca lotes
      final lotes = await _loteRepo.getLotesProximosVencimento(
        _config.diasAntes + 1,
      );

      // monta nomes
      final produtoIds = lotes.map((e) => e.produtoId).toSet();

      final Map<int, String> nomes = {};

      for (final id in produtoIds) {
        final produto = await _produtoRepo.getById(id);

        if (produto != null) {
          nomes[id] = produto.nome;
        }
      }

      // reagenda notificações
      await NotificationService.instance.scheduleForAllLotes(
        lotes,
        nomes,
        _config,
      );

      _status = NotifSaveStatus.saved;
    } catch (e) {
      _status = NotifSaveStatus.error;
      _error = 'Erro ao salvar: $e';
    } finally {
      notifyListeners();
    }
  }

  // ───────────────── TEST ─────────────────

  Future<void> testar() async {
    final granted = await _requestAllPermissions();

    if (!granted) {
      _error =
      'Permissão negada. Verifique as configurações do sistema.';

      _status = NotifSaveStatus.error;

      notifyListeners();

      return;
    }

    await NotificationService.instance.showTest();
  }

  // ───────────────── RESET ─────────────────

  void resetStatus() {
    _status = NotifSaveStatus.idle;
    _error = null;

    notifyListeners();
  }
}