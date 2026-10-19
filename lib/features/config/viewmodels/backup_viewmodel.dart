import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../core/backup/backup_config.dart';
import '../../../core/backup/backup_config_repository.dart';
import '../../../core/backup/backup_scheduler.dart';
import '../../../core/backup/google_drive_backup_service.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class BackupViewModel extends BaseViewModel with WidgetsBindingObserver {
  final BackupConfigRepository _repo;
  final GoogleDriveBackupService _drive;

  BackupViewModel({
    BackupConfigRepository? repo,
    GoogleDriveBackupService? drive,
  })  : _repo = repo ?? BackupConfigRepository(),
        _drive = drive ?? GoogleDriveBackupService() {
    _carregar();
    _startTimer();
    WidgetsBinding.instance.addObserver(this);
  }

  BackupConfig _config = const BackupConfig();
  BackupConfig get config => _config;

  bool _fazendoBackup = false;
  bool get fazendoBackup => _fazendoBackup;

  bool _restaurando = false;
  bool get restaurando => _restaurando;

  Timer? _timer;

  static const _semConexaoMsg =
      'Sem conexão com a internet. Conecte-se e tente novamente.';

  /// Faz uma resolução DNS real em vez de só checar o tipo de conexão
  /// (wi-fi/dados), assim detecta também o caso de estar "conectado" a uma
  /// rede sem saída de internet de fato.
  Future<bool> _temConexao() async {
    try {
      final resultado = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return resultado.isNotEmpty && resultado.first.rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _carregar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _carregar();
    }
  }

  Future<void> _carregar() async {
    _config = await _repo.carregar();
    if (_config.ativado && _config.contaEmail == null) {
      final conta = await _drive.tentarReconectarSilenciosamente();
      _config = _config.copyWith(contaEmail: conta?.email);
    }
    safeNotify();
  }

  Future<void> ativar() async {
    await run<void>(
          () async {
        if (!await _temConexao()) {
          throw GoogleDriveBackupException(_semConexaoMsg);
        }

        final conta = await _drive.conectar();
        await _repo.salvarAtivado(true);
        await _repo.salvarContaEmail(conta.email);

        _config = _config.copyWith(
          ativado: true,
          contaEmail: conta.email,
        );

        // Agenda o backup automático.
        await BackupScheduler.agendar(
          intervaloMinutos: _config.intervaloMinutos,
        );

        // Faz o primeiro backup de verdade.
        await _drive.fazerBackup();

        // Só registra como último backup depois que deu certo.
        final agora = DateTime.now();

        await _repo.salvarUltimoBackup(agora);

        _config = _config.copyWith(
          ultimoBackupEm: agora,
        );
      },
      onError: (e) => e is GoogleDriveBackupException
          ? e.toString()
          : 'Não foi possível ativar o backup em nuvem: $e',
    );
  }

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

    if (!await _temConexao()) {
      setStatus(ViewStatus.error, error: _semConexaoMsg);
      _fazendoBackup = false;
      safeNotify();
      return;
    }

    final agora = DateTime.now();
    await _repo.salvarUltimaTentativa(agora);
    _config = _config.copyWith(ultimaTentativaEm: agora);
    try {
      await _drive.fazerBackup();
      _config = _config.copyWith(ultimoBackupEm: agora);
      await _repo.salvarUltimoBackup(agora);
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

  Future<bool> restaurarBackup() async {
    _restaurando = true;
    safeNotify();

    if (!await _temConexao()) {
      setStatus(ViewStatus.error, error: _semConexaoMsg);
      _restaurando = false;
      safeNotify();
      return false;
    }

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