import 'dart:async';
import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../models/lote.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';

// Representa um produto com seus lotes para exibição na home
class ProdutoComLotes {
  final Produto     produto;
  final List<Lote>  lotes;

  const ProdutoComLotes({required this.produto, required this.lotes});

  // Lote mais próximo de vencer (ativo)
  Lote? get loteAtivo {
    final ativos = lotes.where((l) => l.status == LoteStatus.ativo).toList()
      ..sort((a, b) => a.dataValidade.compareTo(b.dataValidade));
    return ativos.isEmpty ? null : ativos.first;
  }

  int get estoqueTotal =>
      lotes.where((l) => l.status == LoteStatus.ativo)
          .fold(0, (s, l) => s + l.quantidade);

  bool get temLoteVencendo =>
      lotes.any((l) => l.status == LoteStatus.ativo && l.diasParaVencer <= 7);
}

class HomeViewModel extends ChangeNotifier {
  final ProdutoRepository _produtoRepo;
  final LoteRepository    _loteRepo;

  HomeViewModel({ProdutoRepository? produtoRepo, LoteRepository? loteRepo})
      : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo    = loteRepo    ?? LoteRepository() {
    search('');
  }

  // ── State ──────────────────────────────────────────────────────────────────

  List<ProdutoComLotes> _items     = [];
  bool                  _isLoading = false;
  String?               _error;
  int                   _selectedCategoryIndex = 0;
  int                   _selectedNavIndex      = 0;
  Timer?                _debounce;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<ProdutoComLotes> get items               => List.unmodifiable(_items);
  bool                  get isLoading           => _isLoading;
  String?               get error               => _error;
  int                   get selectedCategoryIndex => _selectedCategoryIndex;
  int                   get selectedNavIndex    => _selectedNavIndex;

  // ── Search ─────────────────────────────────────────────────────────────────

  void onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => search(q));
  }

  Future<void> search(String query) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final produtos = await _produtoRepo.search(query);

      // Carrega os lotes de cada produto em paralelo
      final futures = produtos.map((p) async {
        final lotes = await _loteRepo.getByProduto(p.id!);
        return ProdutoComLotes(produto: p, lotes: lotes);
      });

      _items = await Future.wait(futures);
    } catch (e) {
      _error = 'Erro ao buscar produtos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => search('');

  // ── Nav ────────────────────────────────────────────────────────────────────

  void selectCategory(int i) {
    _selectedCategoryIndex = i;
    notifyListeners();
  }

  void selectNav(int i) {
    if (_selectedNavIndex == i) return;
    _selectedNavIndex = i;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}