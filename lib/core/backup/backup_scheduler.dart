import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'backup_config.dart';
import 'backup_config_repository.dart';
import 'google_drive_backup_service.dart';

const kTarefaBackupDiario = 'mystock_backup_diario';
const kFilaBackupAoFechar = 'mystock_backup_ao_fechar';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    final agora = DateTime.now();
    final repo = BackupConfigRepository();
    await repo.salvarUltimaTentativa(agora);

    if (kDebugMode) print('WorkManager: Worker ativado para: $task às $agora');

    if (task != kTarefaBackupDiario) return true;

    try {
      final config = await repo.carregar();
      if (!config.ativado) return true;

      await GoogleDriveBackupService().fazerBackupEmSegundoPlano();

      await repo.salvarUltimoBackup(agora);
      await repo.salvarUltimoErro(null);

      return true;
    } catch (e) {
      if (kDebugMode) print('WorkManager: Falha no backup background: $e');
      await repo.salvarUltimoErro(e.toString());
      return false;
    }
  });
}

class BackupScheduler {
  const BackupScheduler._();

  static Future<void> inicializar() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> agendar({required int intervaloMinutos}) async {
    await _registrar(
      intervalo: _normalizarIntervalo(intervaloMinutos),
      delayInicial: const Duration(seconds: 10),
    );
  }

  static Future<void> sincronizarAoAbrirApp() async {
    final config = await BackupConfigRepository().carregar();
    if (!config.ativado) return;

    final intervalo = _normalizarIntervalo(config.intervaloMinutos);
    await _registrar(intervalo: intervalo, delayInicial: intervalo);
  }

  static Duration _normalizarIntervalo(int intervaloMinutos) => Duration(
    minutes: intervaloMinutos < kIntervaloMinimoMinutos
        ? kIntervaloMinimoMinutos
        : intervaloMinutos,
  );

  static Future<void> _registrar({
    required Duration intervalo,
    required Duration delayInicial,
  }) async {
    await Workmanager().registerPeriodicTask(
      kTarefaBackupDiario,
      kTarefaBackupDiario,
      frequency: intervalo,
      initialDelay: delayInicial,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'myStock',
        notificationText: 'Sincronizando backup automático...',
      ),
    );
  }

  static Future<void> cancelar() async {
    await Workmanager().cancelByUniqueName(kTarefaBackupDiario);
    await Workmanager().cancelByUniqueName(kFilaBackupAoFechar);
  }

  static Future<void> agendarAoFechar() async {
    await Workmanager().registerOneOffTask(
      kFilaBackupAoFechar,
      kTarefaBackupDiario,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'myStock',
        notificationText: 'Salvando dados na nuvem...',
      ),
    );
  }
}