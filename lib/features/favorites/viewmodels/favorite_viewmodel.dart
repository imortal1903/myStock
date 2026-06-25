import 'package:flutter/material.dart';

// Importa Produto do crud pois favorites depende do mesmo modelo de produto.
// Se favorites tiver seu próprio modelo no futuro, substituir este import.
import '../../crud/models/produto.dart';

class FavoriteViewModel extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────

  final Map<int, Produto> _favoritos = {};
  final bool _isLoading = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  // Retorna uma lista imutável para maior segurança
  List<Produto> get favoritos => List.unmodifiable(_favoritos.values);
  bool          get isLoading  => _isLoading;
  bool          get isEmpty    => _favoritos.isEmpty;

  bool isFavorite(int id) => _favoritos.containsKey(id);

  // ── Actions ────────────────────────────────────────────────────────────────

  void toggle(Produto produto) {
    final id = produto.id;
    if (id == null) return;

    if (_favoritos.remove(id) == null) {
      _favoritos[id] = produto;
    }
    notifyListeners();
  }
}
