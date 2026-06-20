import 'package:flutter/material.dart';

// Importa Produto do crud pois favorites depende do mesmo modelo de produto.
// Se favorites tiver seu próprio modelo no futuro, substituir este import.
import '../../crud/models/produto.dart';

class FavoriteViewModel extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────

  final List<Produto> _favoritos = [];
  final bool _isLoading = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Produto> get favoritos  => List.unmodifiable(_favoritos);
  bool          get isLoading  => _isLoading;
  bool          get isEmpty    => _favoritos.isEmpty;

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Adiciona ou remove um produto dos favoritos.
  void toggle(Produto produto) {
    final existe = _favoritos.any((p) => p.id == produto.id);
    if (existe) {
      _favoritos.removeWhere((p) => p.id == produto.id);
    } else {
      _favoritos.add(produto);
    }
    notifyListeners();
  }

  bool isFavorito(String id) => _favoritos.any((p) => p.id == id);
}