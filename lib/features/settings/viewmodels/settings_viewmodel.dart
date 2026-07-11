import 'package:flutter/material.dart';

import '../../../core/theme/theme_controller.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

/// ViewModel da tela de Configurações.
///
/// Faz a ponte entre [SettingsRepository] (persistência) e
/// [ThemeController] (estado do tema em tempo real usado pelo MaterialApp).
class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _repository;
  final ThemeController _themeController;

  SettingsViewModel({
    required SettingsRepository repository,
    required ThemeController themeController,
  })  : _repository = repository,
        _themeController = themeController {
    _carregar();
  }

  AppSettings _settings = const AppSettings();
  bool _isLoading = true;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeController.themeMode;

  Future<void> _carregar() async {
    _settings = await _repository.carregar();
    _themeController.setTheme(_settings.themeMode);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> definirTema(ThemeMode mode) async {
    if (_settings.themeMode == mode) return;
    _settings = _settings.copyWith(themeMode: mode);
    _themeController.setTheme(mode);
    notifyListeners();
    await _repository.salvarThemeMode(mode);
  }

  Future<void> definirDiasAntecedencia(int dias) async {
    _settings = _settings.copyWith(notificacaoDiasAntecedencia: dias);
    notifyListeners();
    await _repository.salvarDiasAntecedencia(dias);
  }

  Future<void> definirFrequenciaRepeticao(int dias) async {
    _settings = _settings.copyWith(notificacaoFrequenciaRepeticao: dias);
    notifyListeners();
    await _repository.salvarFrequenciaRepeticao(dias);
  }

  Future<void> restaurarPadroes() async {
    await _repository.restaurarPadroes();
    _settings = const AppSettings();
    _themeController.setTheme(_settings.themeMode);
    notifyListeners();
  }
}