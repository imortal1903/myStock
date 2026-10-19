const Object _unset = Object();

/// Menor intervalo aceito pelo WorkManager/JobScheduler do Android para
/// tarefas periódicas.
const int kIntervaloMinimoMinutos = 15;

class BackupConfig {
  final bool ativado;
  final int intervaloMinutos;
  final DateTime? ultimoBackupEm;
  final DateTime? ultimaTentativaEm;
  final String? ultimoErro; // Diagnóstico
  final String? contaEmail;

  const BackupConfig({
    this.ativado = false,
    this.intervaloMinutos = 24 * 60,
    this.ultimoBackupEm,
    this.ultimaTentativaEm,
    this.ultimoErro,
    this.contaEmail,
  });

  BackupConfig copyWith({
    bool? ativado,
    int? intervaloMinutos,
    Object? ultimoBackupEm = _unset,
    Object? ultimaTentativaEm = _unset,
    Object? ultimoErro = _unset,
    Object? contaEmail = _unset,
  }) {
    return BackupConfig(
      ativado: ativado ?? this.ativado,
      intervaloMinutos: intervaloMinutos ?? this.intervaloMinutos,
      ultimoBackupEm: ultimoBackupEm == _unset
          ? this.ultimoBackupEm
          : ultimoBackupEm as DateTime?,
      ultimaTentativaEm: ultimaTentativaEm == _unset
          ? this.ultimaTentativaEm
          : ultimaTentativaEm as DateTime?,
      ultimoErro: ultimoErro == _unset ? this.ultimoErro : ultimoErro as String?,
      contaEmail: contaEmail == _unset ? this.contaEmail : contaEmail as String?,
    );
  }
}
