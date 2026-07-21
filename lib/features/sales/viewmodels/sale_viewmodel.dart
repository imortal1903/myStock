import 'package:flutter/foundation.dart';
import '../../crud/models/lote.dart';
import '../../crud/models/categoria.dart';
import '../../crud/repositories/produto_repository.dart';
import '../../crud/repositories/lote_repository.dart';
import '../../crud/repositories/categoria_repository.dart';
import '../models/item_carrinho.dart';
import '../models/produto_estoque.dart';
import '../repositories/venda_repository.dart';

class SaleViewModel extends ChangeNotifier {
  final ProdutoRepository   _produtoRepo;
  final LoteRepository      _loteRepo;
  final VendaRepository     _vendaRepo;
  final CategoriaRepository _catRepo;

  SaleViewModel({
    ProdutoRepository?   produtoRepo,
    LoteRepository?      loteRepo,
    VendaRepository?     vendaRepo,
    CategoriaRepository? catRepo,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo    = loteRepo    ?? LoteRepository(),
        _vendaRepo   = vendaRepo   ?? VendaRepository(),
        _catRepo     = catRepo     ?? CategoriaRepository() {
    _loadCategorias();
    _executarBusca('');
  }

  // ── Categorias (filtro de busca) ────────────────────────────────────────────

  List<Categoria> _categorias = [];
  List<Categoria> get categorias => List.unmodifiable(_categorias);

  int? _categoriaFiltroId;
  int? get categoriaFiltroId => _categoriaFiltroId;

  /// A categoria atualmente selecionada no filtro, ou null se for "Todas".
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
      notifyListeners();
    } catch (_) {
      // Sem categorias cadastradas ainda; o filtro simplesmente não aparece.
    }
  }

  /// Filtra os resultados por categoria, mantendo o termo pesquisado.
  /// Passe `null` para voltar a mostrar todas as categorias.
  Future<void> filtrarPorCategoria(int? categoriaId) async {
    if (_categoriaFiltroId == categoriaId) return;
    _categoriaFiltroId = categoriaId;
    await _executarBusca(_ultimoTermo);
  }

  // ── Busca de produtos (já com resumo de estoque) ────────────────────────────
  List<ProdutoEstoque> _resultados = [];
  List<ProdutoEstoque> get resultados => _resultados;

  bool _buscando = false;
  bool get buscando => _buscando;

  String? _erroBusca;
  String? get erroBusca => _erroBusca;

  String _ultimoTermo = '';

  Future<void> buscar(String termo) {
    _ultimoTermo = termo;
    return _executarBusca(termo);
  }

  Future<void> refresh() async {
    await _loadCategorias();
    await _executarBusca(_ultimoTermo);
  }

  Future<void> _executarBusca(String termo) async {
    _buscando = true;
    notifyListeners();
    try {
      final produtos = await _produtoRepo.search(
        termo,
        categoriaId: _categoriaFiltroId,
      );
      final resultado = <ProdutoEstoque>[];
      for (final p in produtos) {
        final lotes = await _loteRepo.getByProduto(p.id!);
        resultado.add(ProdutoEstoque(produto: p, lotes: lotes));
      }
      _resultados = resultado;
      _erroBusca = null;
    } catch (_) {
      _erroBusca = 'Erro ao buscar produtos.';
    } finally {
      _buscando = false;
      notifyListeners();
    }
  }

  // ── Carrinho ───────────────────────────────────────────────────────────────
  final List<ItemCarrinho> _carrinho = [];
  List<ItemCarrinho> get carrinho => List.unmodifiable(_carrinho);

  double get totalCarrinho => _carrinho.fold(0, (acc, i) => acc + i.subtotal);
  int get quantidadeItens => _carrinho.fold(0, (acc, i) => acc + i.quantidade);

  String? _erroCarrinho;
  String? get erroCarrinho => _erroCarrinho;

  List<Lote> lotesDisponiveis(ProdutoEstoque item) => item.lotes
      .where((l) => l.status == LoteStatus.ativo && l.quantidade > 0)
      .toList();

  Future<void> adicionarAoCarrinho(ProdutoEstoque item, Lote lote, {int quantidade = 1}) async {
    _erroCarrinho = null;
    final produto = item.produto;

    final existenteIdx =
    _carrinho.indexWhere((i) => i.produto.id == produto.id && i.lote.id == lote.id);
    final jaNoCarrinho = existenteIdx >= 0 ? _carrinho[existenteIdx].quantidade : 0;

    if (jaNoCarrinho + quantidade > lote.quantidade) {
      _erroCarrinho =
      'Estoque insuficiente para "${produto.nome}" (disponível: ${lote.quantidade}).';
      notifyListeners();
      return;
    }

    if (existenteIdx >= 0) {
      _carrinho[existenteIdx].quantidade += quantidade;
    } else {
      _carrinho.add(ItemCarrinho(
        produto: produto,
        lote: lote,
        quantidade: quantidade,
        precoUnitario: lote.precoCusto ?? 0,
      ));
    }
    notifyListeners();
  }

  void atualizarQuantidade(ItemCarrinho item, int quantidade) {
    if (quantidade <= 0) {
      removerDoCarrinho(item);
      return;
    }
    if (quantidade > item.lote.quantidade) {
      _erroCarrinho =
      'Estoque insuficiente para "${item.produto.nome}" (disponível: ${item.lote.quantidade}).';
      notifyListeners();
      return;
    }
    item.quantidade = quantidade;
    _erroCarrinho = null;
    notifyListeners();
  }

  void atualizarPreco(ItemCarrinho item, double preco) {
    item.precoUnitario = preco;
    notifyListeners();
  }

  void removerDoCarrinho(ItemCarrinho item) {
    _carrinho.remove(item);
    notifyListeners();
  }

  void limparCarrinho() {
    _carrinho.clear();
    _erroCarrinho = null;
    notifyListeners();
  }

  // ── Checkout ───────────────────────────────────────────────────────────────
  bool _finalizando = false;
  bool get finalizando => _finalizando;

  Future<int?> finalizarVenda() async {
    if (_carrinho.isEmpty) {
      _erroCarrinho = 'Adicione ao menos um item ao carrinho.';
      notifyListeners();
      return null;
    }

    _finalizando = true;
    _erroCarrinho = null;
    notifyListeners();

    try {
      final vendaId = await _vendaRepo.finalizarVenda(_carrinho);
      limparCarrinho();
      await refresh();
      return vendaId;
    } catch (e) {
      _erroCarrinho =
      e is EstoqueInsuficienteException ? e.toString() : 'Não foi possível finalizar a venda.';
      return null;
    } finally {
      _finalizando = false;
      notifyListeners();
    }
  }
}