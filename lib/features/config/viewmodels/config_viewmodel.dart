import 'package:flutter/material.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/database/db_seeder.dart';
import '../models/app_config.dart';
import '../repositories/config_repository.dart';

/// ViewModel da tela de Configurações.
/// Faz a ponte entre [ConfigRepository] (persistência) e
/// [ThemeController] (estado do tema em tempo real usado pelo MaterialApp).
class ConfigViewModel extends ChangeNotifier {
  final ConfigRepository _repository;
  final ThemeController _themeController;

  ConfigViewModel({
    required ConfigRepository repository,
    required ThemeController themeController,
  })  : _repository = repository,
        _themeController = themeController {
    _carregar();
  }

  AppConfig _config = const AppConfig();
  bool _isLoading = true;
  bool _isGeneratingData = false;

  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  bool get isGeneratingData => _isGeneratingData;
  ThemeMode get themeMode => _themeController.themeMode;

  Future<void> _carregar() async {
    _config = await _repository.carregar();
    _themeController.setTheme(_config.themeMode);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> definirTema(ThemeMode mode) async {
    if (_config.themeMode == mode) return;
    _config = _config.copyWith(themeMode: mode);
    _themeController.setTheme(mode);
    notifyListeners();
    await _repository.salvarThemeMode(mode);
  }

  Future<void> restaurarPadroes() async {
    await _repository.restaurarPadroes();
    _config = const AppConfig();
    _themeController.setTheme(_config.themeMode);
    notifyListeners();
  }

  Future<void> gerarDadosTeste() async {
    _isGeneratingData = true;
    notifyListeners();
    try {
      await DbSeeder.popularBanco();
    } finally {
      _isGeneratingData = false;
      notifyListeners();
    }
  }
}
