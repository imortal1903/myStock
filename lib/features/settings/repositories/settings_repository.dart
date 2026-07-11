import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Responsável por persistir e recuperar as preferências do usuário.
///
/// Usa SharedPreferences (armazenamento local de chave-valor) — não
/// precisa de uma tabela no SQLite pois são poucos valores simples.
class SettingsRepository {
  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyDiasAntecedencia = 'settings_dias_antecedencia';
  static const _keyFrequenciaRepeticao = 'settings_frequencia_repeticao';

  Future<AppSettings> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    return AppSettings(
      themeMode: ThemeMode.values[themeIndex],
      notificacaoDiasAntecedencia: prefs.getInt(_keyDiasAntecedencia) ?? 7,
      notificacaoFrequenciaRepeticao:
      prefs.getInt(_keyFrequenciaRepeticao) ?? 1,
    );
  }

  Future<void> salvarThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<void> salvarDiasAntecedencia(int dias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDiasAntecedencia, dias);
  }

  Future<void> salvarFrequenciaRepeticao(int dias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFrequenciaRepeticao, dias);
  }

  Future<void> restaurarPadroes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyThemeMode);
    await prefs.remove(_keyDiasAntecedencia);
    await prefs.remove(_keyFrequenciaRepeticao);
  }
}