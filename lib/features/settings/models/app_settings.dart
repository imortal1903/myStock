import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;
  final int notificacaoDiasAntecedencia;
  final int notificacaoFrequenciaRepeticao;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notificacaoDiasAntecedencia = 7,
    this.notificacaoFrequenciaRepeticao = 1,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? notificacaoDiasAntecedencia,
    int? notificacaoFrequenciaRepeticao,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificacaoDiasAntecedencia:
      notificacaoDiasAntecedencia ?? this.notificacaoDiasAntecedencia,
      notificacaoFrequenciaRepeticao:
      notificacaoFrequenciaRepeticao ?? this.notificacaoFrequenciaRepeticao,
    );
  }
}