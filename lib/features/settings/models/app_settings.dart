import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;

  const AppSettings({
    this.themeMode = ThemeMode.system,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
    );
  }
}