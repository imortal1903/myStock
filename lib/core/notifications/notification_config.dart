import 'dart:convert';

/// Configuração de notificações de validade persistida pelo usuário.
class NotificationConfig {
  final bool ativado;

  /// Quantos dias antes do vencimento a primeira notificação é enviada.
  final int diasAntes;

  /// Hora do dia (0–23).
  final int hora;

  /// Minuto do dia (0–59).
  final int minuto;

  /// Intervalo em horas entre notificações repetidas.
  /// 24 = diário, 48 = a cada 2 dias, 72 = a cada 3 dias, 168 = semanal.
  final int intervaloHoras;

  const NotificationConfig({
    this.ativado        = true,
    this.diasAntes      = 3,
    this.hora           = 9,
    this.minuto         = 0,
    this.intervaloHoras = 24,
  });

  // ── Serialização ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'ativado':        ativado,
    'diasAntes':      diasAntes,
    'hora':           hora,
    'minuto':         minuto,
    'intervaloHoras': intervaloHoras,
  };

  factory NotificationConfig.fromMap(Map<String, dynamic> m) =>
      NotificationConfig(
        ativado:        m['ativado']        as bool? ?? true,
        diasAntes:      m['diasAntes']      as int?  ?? 3,
        hora:           m['hora']           as int?  ?? 9,
        minuto:         m['minuto']         as int?  ?? 0,
        intervaloHoras: m['intervaloHoras'] as int?  ?? 24,
      );

  String toJson() => jsonEncode(toMap());

  factory NotificationConfig.fromJson(String s) =>
      NotificationConfig.fromMap(jsonDecode(s) as Map<String, dynamic>);

  NotificationConfig copyWith({
    bool? ativado,
    int?  diasAntes,
    int?  hora,
    int?  minuto,
    int?  intervaloHoras,
  }) =>
      NotificationConfig(
        ativado:        ativado        ?? this.ativado,
        diasAntes:      diasAntes      ?? this.diasAntes,
        hora:           hora           ?? this.hora,
        minuto:         minuto         ?? this.minuto,
        intervaloHoras: intervaloHoras ?? this.intervaloHoras,
      );

  // ── Labels de UI ──────────────────────────────────────────────────────────

  String get intervaloLabel {
    switch (intervaloHoras) {
      case 24:  return 'Todo dia';
      case 48:  return 'A cada 2 dias';
      case 72:  return 'A cada 3 dias';
      case 168: return 'Semanalmente';
      default:  return 'A cada ${intervaloHoras}h';
    }
  }

  String get horarioLabel =>
      '${hora.toString().padLeft(2, '0')}:'
          '${minuto.toString().padLeft(2, '0')}';

  // ── Opções disponíveis ────────────────────────────────────────────────────

  static const List<int> opDiasAntes      = [1, 2, 3, 5, 7, 14, 30];
  static const List<int> opIntervaloHoras = [24, 48, 72, 168];
}
