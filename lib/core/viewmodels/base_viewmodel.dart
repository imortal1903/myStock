import 'package:flutter/foundation.dart';

enum ViewStatus { idle, loading, success, error }

/// Base comum: elimina a repetição de status/erro/try-catch nos ViewModels.
abstract class BaseViewModel extends ChangeNotifier {
  ViewStatus _status = ViewStatus.idle;
  String? _errorMessage;
  bool _disposed = false;

  ViewStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ViewStatus.loading;
  bool get hasError => _status == ViewStatus.error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @protected
  void safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @protected
  void setStatus(ViewStatus s, {String? error}) {
    _status = s;
    _errorMessage = error;
    safeNotify();
  }

  void resetStatus() {
    if (_status == ViewStatus.idle && _errorMessage == null) return;
    setStatus(ViewStatus.idle);
  }

  /// Executa [action] cuidando de loading/success/error.
  /// Retorna null em caso de falha.
  @protected
  Future<T?> run<T>(
      Future<T> Function() action, {
        String Function(Object error)? onError,
        bool markSuccess = true,
      }) async {
    setStatus(ViewStatus.loading);
    try {
      final result = await action();
      if (markSuccess) {
        setStatus(ViewStatus.success);
      } else {
        setStatus(ViewStatus.idle);
      }
      return result;
    } catch (e) {
      setStatus(
        ViewStatus.error,
        error: onError?.call(e) ?? 'Erro: $e',
      );
      return null;
    }
  }
}