import 'package:flutter/material.dart';

class AppConfig {
  final ThemeMode themeMode;

  const AppConfig({
    this.themeMode = ThemeMode.system,
  });

  AppConfig copyWith({
    ThemeMode? themeMode,
  }) {
    return AppConfig(
      themeMode: themeMode ?? this.themeMode,
    );
  }
}