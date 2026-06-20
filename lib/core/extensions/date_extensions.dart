extension DateOnlyExtension on DateTime {
  /// Retorna a data sem considerar hora, minuto, segundo...
  DateTime get dateOnly => DateTime(year, month, day);

  /// Esta data é anterior à outra (ignorando horário)?
  bool isBeforeDate(DateTime other) =>
      dateOnly.isBefore(other.dateOnly);

  /// Esta data é posterior à outra (ignorando horário)?
  bool isAfterDate(DateTime other) =>
      dateOnly.isAfter(other.dateOnly);

  /// É o mesmo dia?
  bool isSameDate(DateTime other) =>
      year == other.year &&
          month == other.month &&
          day == other.day;

  /// Diferença em dias ignorando horário.
  int differenceInDays(DateTime other) =>
      dateOnly.difference(other.dateOnly).inDays;
}