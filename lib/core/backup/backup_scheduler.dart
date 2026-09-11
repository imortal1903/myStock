import 'package:workmanager/workmanager.dart';

import 'backup_config.dart';
import 'backup_config_repository.dart';
import 'google_drive_backup_service.dart';

/// Nome único da tarefa periódica registrada no WorkManager — usado tanto
/// para agendar quanto para cancelar.
const kTarefaBackupDiario = 'mystock_backup_diario';

/// Nome único da tarefa AVULSA disparada quando o app vai para segundo
/// plano (ver `didChangeAppLifecycleState` em main.dart). Complementa o
/// agendamento periódico, cobrindo o padrão de uso mais comum — "abriu o
/// app, mexeu, fechou" — sem precisar esperar o intervalo automático
/// passar. Usa um nome de fila diferente do periódico (para não
/// cancelar/substituir um pelo outro), mas reaproveita o mesmo "task
/// name" (`kTarefaBackupDiario`) para cair no mesmo tratamento dentro de
/// `callbackDispatcher`.
const kFilaBackupAoFechar = 'mystock_backup_ao_fechar';

/// Ponto de entrada executado pelo sistema operacional em segundo plano,
/// possivelmente com o app totalmente fechado (processo Dart separado do
/// da UI). Por isso NUNCA pode depender de estado do app em memória
/// (Provider, ViewModels, etc.) — tudo que precisa é recriado aqui dentro.
/// Atende tanto a tarefa periódica quanto a avulsa disparada ao fechar o
/// app (ambas usam este mesmo "task name": kTarefaBackupDiario).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kTarefaBackupDiario) return true;

    try {
      final config = await BackupConfigRepository().carregar();
      if (!config.ativado) return true;

      await GoogleDriveBackupService().fazerBackupEmSegundoPlano();
      await BackupConfigRepository().salvarUltimoBackup(DateTime.now());
      return true;
    } catch (_) {
      return false;
    }
  });
}

class BackupScheduler {
  const BackupScheduler._();

  /// Chamar uma única vez, no `main()`, antes de `runApp()`.
  static Future<void> inicializar() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// Agenda o backup automático.
  static Future<void> agendar({required int intervaloMinutos}) async {
    final intervalo = Duration(
      minutes: intervaloMinutos < kIntervaloMinimoMinutos
          ? kIntervaloMinimoMinutos
          : intervaloMinutos,
    );

    await Workmanager().cancelByUniqueName(kTarefaBackupDiario);

    await Workmanager().registerPeriodicTask(
      kTarefaBackupDiario,
      kTarefaBackupDiario,
      frequency: intervalo,
      // Removido initialDelay para que a primeira execução ocorra na primeira 
      // janela de oportunidade, e não apenas após um intervalo completo.
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'myStock',
        notificationText: 'Fazendo backup em nuvem...',
      ),
    );
  }

  static Future<void> cancelar() async {
    await Workmanager().cancelByUniqueName(kTarefaBackupDiario);
    await Workmanager().cancelByUniqueName(kFilaBackupAoFechar);
  }

  /// Enfileira uma tentativa de backup quando o app é fechado/pausado.
  static Future<void> agendarAoFechar() async {
    // Usamos ExistingWorkPolicy.replace para garantir que a intenção mais 
    // recente de backup seja processada.
    await Workmanager().registerOneOffTask(
      kFilaBackupAoFechar,
      kTarefaBackupDiario,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'myStock',
        notificationText: 'Salvando dados na nuvem...',
      ),
    );
  }
}
