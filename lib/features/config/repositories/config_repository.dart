import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config.dart';
class ConfigRepository {
  static const _keyThemeMode = 'settings_theme_mode';

  Future<AppConfig> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    return AppConfig(themeMode: ThemeMode.values[themeIndex]);
  }

  Future<void> salvarThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<void> restaurarPadroes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyThemeMode);
  }
}