import '../../../core/backup/backup_config.dart';
import '../../../core/backup/backup_config_repository.dart';
import '../../../core/backup/backup_scheduler.dart';
import '../../../core/backup/google_drive_backup_service.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class BackupViewModel extends BaseViewModel {
  final BackupConfigRepository _repo;
  final GoogleDriveBackupService _drive;

  BackupViewModel({
    BackupConfigRepository? repo,
    GoogleDriveBackupService? drive,
  })  : _repo = repo ?? BackupConfigRepository(),
        _drive = drive ?? GoogleDriveBackupService() {
    _carregar();
  }

  BackupConfig _config = const BackupConfig();
  BackupConfig get config => _config;

  /// Loading próprio para "fazer backup agora" — independente do
  /// `status`/`isLoading` herdado, que aqui é usado para ativar/desativar.
  /// Os dois podem, em tese, ocorrer em momentos diferentes, então cada
  /// ação tem seu próprio indicador (mesmo raciocínio de VendaViewModel).
  bool _fazendoBackup = false;
  bool get fazendoBackup => _fazendoBackup;

  bool _restaurando = false;
  bool get restaurando => _restaurando;

  Future<void> _carregar() async {
    _config = await _repo.carregar();
    if (_config.ativado) {
      final conta = await _drive.tentarReconectarSilenciosamente();
      _config = _config.copyWith(contaEmail: conta?.email);
    }
    safeNotify();
  }

  /// Ativa o backup em nuvem: pede login no Google (se preciso), agenda o
  /// backup automático no horário já configurado, e já dispara um backup
  /// imediato — pedido explicitamente para "ativar" não ficar sem efeito
  /// visível até o próximo horário agendado.
  Future<void> ativar() async {
    await run<void>(
          () async {
        final conta = await _drive.conectar();

        // Login e agendamento primeiro, SEM marcar `ativado` ainda — se
        // qualquer passo daqui falhar (ex.: agendar() rejeitando por
        // faltar a config nativa do foreground service), o switch
        // continua desligado e nada fica salvo pela metade.
        await BackupScheduler.agendar(intervaloMinutos: _config.intervaloMinutos);
        await _drive.fazerBackup();

        // Só chega aqui se login, agendamento e o backup imediato deram
        // certo — agora sim persiste como ativado.
        _config = _config.copyWith(
          ativado: true,
          contaEmail: conta.email,
          ultimoBackupEm: DateTime.now(),
        );
        await _repo.salvarAtivado(true);
        await _repo.salvarContaEmail(conta.email);
        await _repo.salvarUltimoBackup(_config.ultimoBackupEm!);
      },
      onError: (e) => e is GoogleDriveBackupException
          ? e.toString()
          : 'Não foi possível ativar o backup em nuvem: $e',
    );
  }

  /// Desativa o backup: cancela o agendamento e desconecta a conta. Não
  /// apaga o backup já existente no Drive — só para de mantê-lo
  /// atualizado.
  Future<void> desativar() async {
    await run<void>(
          () async {
        await BackupScheduler.cancelar();
        await _drive.desconectar();
        _config = _config.copyWith(ativado: false, contaEmail: null);
        await _repo.salvarAtivado(false);
        await _repo.salvarContaEmail(null);
      },
      onError: (e) => 'Erro ao desativar o backup em nuvem.',
    );
  }

  Future<void> definirIntervalo(int intervaloMinutos) async {
    if (_config.intervaloMinutos == intervaloMinutos) return;
    final intervaloAnterior = _config.intervaloMinutos;
    _config = _config.copyWith(intervaloMinutos: intervaloMinutos);
    safeNotify();
    await _repo.salvarIntervaloMinutos(intervaloMinutos);

    if (!_config.ativado) return;

    try {
      await BackupScheduler.agendar(intervaloMinutos: intervaloMinutos);
    } catch (e) {
      // Reverte o intervalo exibido — se o reagendamento falhou, o
      // agendamento antigo (se houver) continua valendo, então mostrar o
      // valor novo como se tivesse dado certo seria enganoso.
      _config = _config.copyWith(intervaloMinutos: intervaloAnterior);
      await _repo.salvarIntervaloMinutos(intervaloAnterior);
      setStatus(
        ViewStatus.error,
        error: 'Não foi possível atualizar o intervalo do backup automático: $e',
      );
    }
  }

  Future<void> fazerBackupAgora() async {
    _fazendoBackup = true;
    safeNotify();
    try {
      await _drive.fazerBackup();
      _config = _config.copyWith(ultimoBackupEm: DateTime.now());
      await _repo.salvarUltimoBackup(_config.ultimoBackupEm!);
      setStatus(ViewStatus.success);
    } catch (e) {
      setStatus(
        ViewStatus.error,
        error: e is GoogleDriveBackupException
            ? e.toString()
            : 'Não foi possível fazer backup agora.',
      );
    } finally {
      _fazendoBackup = false;
      safeNotify();
    }
  }

  /// Retorna `true` se havia um backup na nuvem e a restauração deu certo.
  /// Depois de restaurar, o app precisa ser reaberto — os ViewModels já
  /// carregados em memória não sabem que o arquivo por trás mudou.
  Future<bool> restaurarBackup() async {
    _restaurando = true;
    safeNotify();
    try {
      final restaurou = await _drive.restaurarBackup();
      setStatus(
        restaurou ? ViewStatus.success : ViewStatus.error,
        error: restaurou ? null : 'Nenhum backup encontrado na nuvem ainda.',
      );
      return restaurou;
    } catch (e) {
      setStatus(
        ViewStatus.error,
        error: e is GoogleDriveBackupException
            ? e.toString()
            : 'Não foi possível restaurar o backup.',
      );
      return false;
    } finally {
      _restaurando = false;
      safeNotify();
    }
  }
}