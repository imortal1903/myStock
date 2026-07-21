import 'dart:async';
import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../models/lote.dart';
import '../models/categoria.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';
import '../repositories/categoria_repository.dart';

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
  final ProdutoRepository   _produtoRepo;
  final LoteRepository      _loteRepo;
  final CategoriaRepository _catRepo;

  HomeViewModel({
    ProdutoRepository?   produtoRepo,
    LoteRepository?      loteRepo,
    CategoriaRepository? catRepo,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo    = loteRepo    ?? LoteRepository(),
        _catRepo     = catRepo     ?? CategoriaRepository() {
    _loadCategorias();
    search('');
  }

  // ── State ──────────────────────────────────────────────────────────────────

  List<ProdutoComLotes> _items       = [];
  List<Categoria>       _categorias  = [];
  bool                   _isLoading  = false;
  String?                _error;
  String                 _query               = '';
  int?                   _categoriaFiltroId;
  int                    _selectedCategoryIndex = 0;
  int                    _selectedNavIndex      = 0;
  Timer?                 _debounce;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<ProdutoComLotes> get items                => List.unmodifiable(_items);
  List<Categoria>       get categorias            => List.unmodifiable(_categorias);
  bool                  get isLoading             => _isLoading;
  String?               get error                 => _error;
  String                get query                 => _query;
  int?                  get categoriaFiltroId     => _categoriaFiltroId;
  int                   get selectedCategoryIndex => _selectedCategoryIndex;
  int                   get selectedNavIndex      => _selectedNavIndex;

  /// A categoria atualmente selecionada no filtro, ou null se for "Todas".
  Categoria? get categoriaFiltroSelecionada {
    if (_categoriaFiltroId == null) return null;
    for (final c in _categorias) {
      if (c.id == _categoriaFiltroId) return c;
    }
    return null;
  }

  // ── Categorias (para o filtro de busca) ─────────────────────────────────────

  Future<void> _loadCategorias() async {
    try {
      _categorias = await _catRepo.getAll();
      notifyListeners();
    } catch (_) {
      // Sem categorias cadastradas ainda; o filtro simplesmente não aparece.
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void onSearchChanged(String q) {
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => search(q));
  }

  Future<void> search(String query) async {
    _query     = query;
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final produtos = await _produtoRepo.search(
        query,
        categoriaId: _categoriaFiltroId,
      );

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

  /// Filtra a busca por categoria, mantendo o texto pesquisado.
  /// Passe `null` para voltar a mostrar todas as categorias.
  Future<void> filtrarPorCategoria(int? categoriaId) async {
    if (_categoriaFiltroId == categoriaId) return;
    _categoriaFiltroId = categoriaId;
    await search(_query);
  }

  Future<void> refresh() async {
    await _loadCategorias();
    await search(_query);
  }

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