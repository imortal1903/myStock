import 'package:shared_preferences/shared_preferences.dart';

import 'backup_config.dart';

class BackupConfigRepository {
  static const _kAtivado = 'backup_ativado';
  static const _kIntervaloMinutos = 'backup_intervalo_minutos';
  static const _kUltimoBackup = 'backup_ultimo_em';
  static const _kUltimaTentativa = 'backup_ultima_tentativa';
  static const _kUltimoErro = 'backup_ultimo_erro';
  static const _kContaEmail = 'backup_conta_email';

  Future<BackupConfig> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final ultimoBackupIso = prefs.getString(_kUltimoBackup);
    final ultimaTentativaIso = prefs.getString(_kUltimaTentativa);

    return BackupConfig(
      ativado: prefs.getBool(_kAtivado) ?? false,
      intervaloMinutos: prefs.getInt(_kIntervaloMinutos) ?? (24 * 60),
      ultimoBackupEm:
      ultimoBackupIso != null ? DateTime.tryParse(ultimoBackupIso) : null,
      ultimaTentativaEm:
      ultimaTentativaIso != null ? DateTime.tryParse(ultimaTentativaIso) : null,
      ultimoErro: prefs.getString(_kUltimoErro),
      contaEmail: prefs.getString(_kContaEmail),
    );
  }

  Future<void> salvarAtivado(bool ativado) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAtivado, ativado);
  }

  Future<void> salvarIntervaloMinutos(int minutos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kIntervaloMinutos, minutos);
  }

  Future<void> salvarUltimoBackup(DateTime quando) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUltimoBackup, quando.toIso8601String());

    // Se o backup deu certo, limpa o erro anterior
    await prefs.remove(_kUltimoErro);
  }

  Future<void> salvarUltimaTentativa(DateTime quando) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUltimaTentativa, quando.toIso8601String());
  }

  Future<void> salvarUltimoErro(String? erro) async {
    final prefs = await SharedPreferences.getInstance();
    if (erro == null) {
      await prefs.remove(_kUltimoErro);
    } else {
      await prefs.setString(_kUltimoErro, erro);
    }
  }

  Future<void> salvarContaEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null) {
      await prefs.remove(_kContaEmail);
    } else {
      await prefs.setString(_kContaEmail, email);
    }
  }
}