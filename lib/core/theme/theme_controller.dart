import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeController([ThemeMode initial = ThemeMode.system]) : _themeMode = initial;

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void setTheme(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }
}