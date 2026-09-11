import 'dart:async';

import '../models/produto.dart';
import '../models/lote.dart';
import '../models/categoria.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';
import '../repositories/categoria_repository.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

/// Produto + seus lotes, com os agregados calculados uma única vez.
class ProdutoComLotes {
  final Produto produto;
  final List<Lote> lotes;

  final Lote? loteAtivo;
  final double estoqueTotal;
  final bool temLoteVencendo;
  final int qtdAtivos;
  final int qtdEsgotados;
  final int qtdVencidos;
  final double? precoMedioLotes;

  ProdutoComLotes._({
    required this.produto,
    required this.lotes,
    required this.loteAtivo,
    required this.estoqueTotal,
    required this.temLoteVencendo,
    required this.qtdAtivos,
    required this.qtdEsgotados,
    required this.qtdVencidos,
    required this.precoMedioLotes,
  });

  factory ProdutoComLotes({
    required Produto produto,
    required List<Lote> lotes,
  }) {
    final ativos = <Lote>[];
    var estoque = 0.0;
    var vencendo = false;
    var esgotados = 0;
    var vencidos = 0;
    var somaPrecos = 0.0;

    for (final l in lotes) {
      somaPrecos += l.precoVenda;
      switch (l.status) {
        case LoteStatus.ativo:
          ativos.add(l);
          estoque += l.quantidade;
          if (l.diasParaVencer <= 7) vencendo = true;
        case LoteStatus.esgotado:
          esgotados++;
        case LoteStatus.vencido:
          vencidos++;
      }
    }

    ativos.sort((a, b) => a.dataValidade.compareTo(b.dataValidade));

    return ProdutoComLotes._(
      produto: produto,
      lotes: lotes,
      loteAtivo: ativos.isEmpty ? null : ativos.first,
      estoqueTotal: estoque,
      temLoteVencendo: vencendo,
      qtdAtivos: ativos.length,
      qtdEsgotados: esgotados,
      qtdVencidos: vencidos,
      precoMedioLotes: lotes.isEmpty ? null : somaPrecos / lotes.length,
    );
  }

  /// Valor formatado sozinho — sem rótulo — pra usar onde já existe um
  /// texto próprio explicando o que é (ex.: "Média de preço" em
  /// ProdutoDetailPage).
  String get precoMedioValorFormatado {
    final media = precoMedioLotes;
    if (media == null) return 'Sem preço registrado';
    return 'R\$ ${media.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  /// Com o prefixo "Média:" embutido — pra usar onde o texto aparece
  /// sozinho, sem rótulo ao lado (ex.: card de produto na HomePage).
  String get precoMedioFormatado {
    final media = precoMedioLotes;
    if (media == null) return 'Sem preço registrado';
    return 'Média: R\$ ${media.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

class HomeViewModel extends BaseViewModel {
  final ProdutoRepository _produtoRepo;
  final LoteRepository _loteRepo;
  final CategoriaRepository _catRepo;

  HomeViewModel({
    ProdutoRepository? produtoRepo,
    LoteRepository? loteRepo,
    CategoriaRepository? catRepo,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo = loteRepo ?? LoteRepository(),
        _catRepo = catRepo ?? CategoriaRepository() {
    _loadCategorias();
    search('');
  }

  List<ProdutoComLotes> _items = [];
  List<Categoria> _categorias = [];
  String _query = '';
  int? _categoriaFiltroId;
  int _selectedNavIndex = 0;
  Timer? _debounce;

  /// Evita que uma busca antiga sobrescreva o resultado de uma mais recente.
  int _searchToken = 0;

  List<ProdutoComLotes> get items => List.unmodifiable(_items);
  List<Categoria> get categorias => List.unmodifiable(_categorias);
  String get query => _query;
  int? get categoriaFiltroId => _categoriaFiltroId;
  int get selectedNavIndex => _selectedNavIndex;

  /// Alias mantido para compatibilidade com a UI existente.
  String? get error => errorMessage;

  Categoria? get categoriaFiltroSelecionada {
    if (_categoriaFiltroId == null) return null;
    for (final c in _categorias) {
      if (c.id == _categoriaFiltroId) return c;
    }
    return null;
  }

  Future<void> _loadCategorias() async {
    try {
      _categorias = await _catRepo.getAll();
      safeNotify();
    } catch (_) {
      // Filtro de categoria é opcional.
    }
  }

  void onSearchChanged(String q) {
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => search(q));
  }

  Future<void> search(String query) async {
    _query = query;
    final token = ++_searchToken;

    setStatus(ViewStatus.loading);
    try {
      final produtos = await _produtoRepo.search(
        query,
        categoriaId: _categoriaFiltroId,
      );

      final result = await Future.wait(produtos.map((p) async {
        final lotes = await _loteRepo.getByProduto(p.id!);
        return ProdutoComLotes(produto: p, lotes: lotes);
      }));

      if (token != _searchToken) return; // resultado obsoleto
      _items = result;
      setStatus(ViewStatus.idle);
    } catch (e) {
      if (token != _searchToken) return;
      setStatus(ViewStatus.error, error: 'Erro ao buscar produtos: $e');
    }
  }

  Future<void> filtrarPorCategoria(int? categoriaId) async {
    if (_categoriaFiltroId == categoriaId) return;
    _categoriaFiltroId = categoriaId;
    await search(_query);
  }

  Future<void> refresh() async {
    await _loadCategorias();
    await search(_query);
  }

  void selectNav(int i) {
    if (_selectedNavIndex == i) return;
    _selectedNavIndex = i;
    safeNotify();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}