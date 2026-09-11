extension NumParsing on String? {
  /// Converte texto com vírgula ou ponto em double. Null se inválido.
  double? toDoubleOrNull() {
    final s = this?.trim().replaceAll(',', '.');
    if (s == null || s.isEmpty) return null;
    return double.tryParse(s);
  }

  double toDoubleOrZero() => toDoubleOrNull() ?? 0;

  int? toIntOrNull() {
    final s = this?.trim();
    if (s == null || s.isEmpty) return null;
    return int.tryParse(s);
  }

  int toIntOrZero() => toIntOrNull() ?? 0;

  /// Retorna null quando vazio — útil para colunas nullable.
  String? get nullIfEmpty {
    final s = this?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}