const Object _unset = Object();

/// Menor intervalo aceito pelo WorkManager/JobScheduler do Android para
/// tarefas periódicas — não é uma escolha nossa, é um limite fixo do
/// sistema operacional. Qualquer valor menor é rejeitado/ajustado pelo
/// próprio Android.
const int kIntervaloMinimoMinutos = 15;

/// Configuração do backup em nuvem — persistida via [BackupConfigRepository].
class BackupConfig {
  final bool ativado;

  /// Intervalo entre backups automáticos, em minutos. O WorkManager do
  /// Android não garante execução exata nesse intervalo — trate como uma
  /// preferência, não uma garantia (ver comentários em BackupScheduler).
  final int intervaloMinutos;

  final DateTime? ultimoBackupEm;

  /// E-mail da conta Google conectada, ou `null` se nenhuma estiver
  /// conectada (ex.: backup desativado, ou sessão expirada).
  final String? contaEmail;

  const BackupConfig({
    this.ativado = false,
    this.intervaloMinutos = 24 * 60, // padrão: 1x por dia
    this.ultimoBackupEm,
    this.contaEmail,
  });

  BackupConfig copyWith({
    bool? ativado,
    int? intervaloMinutos,
    Object? ultimoBackupEm = _unset,
    Object? contaEmail = _unset,
  }) {
    return BackupConfig(
      ativado: ativado ?? this.ativado,
      intervaloMinutos: intervaloMinutos ?? this.intervaloMinutos,
      ultimoBackupEm: ultimoBackupEm == _unset
          ? this.ultimoBackupEm
          : ultimoBackupEm as DateTime?,
      contaEmail: contaEmail == _unset ? this.contaEmail : contaEmail as String?,
    );
  }
}