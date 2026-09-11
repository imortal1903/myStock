import 'package:shared_preferences/shared_preferences.dart';

import 'backup_config.dart';

class BackupConfigRepository {
  static const _kAtivado = 'backup_ativado';
  static const _kIntervaloMinutos = 'backup_intervalo_minutos';
  static const _kUltimoBackup = 'backup_ultimo_em';
  static const _kContaEmail = 'backup_conta_email';

  Future<BackupConfig> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final ultimoBackupIso = prefs.getString(_kUltimoBackup);

    return BackupConfig(
      ativado: prefs.getBool(_kAtivado) ?? false,
      intervaloMinutos: prefs.getInt(_kIntervaloMinutos) ?? (24 * 60),
      ultimoBackupEm:
      ultimoBackupIso != null ? DateTime.tryParse(ultimoBackupIso) : null,
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