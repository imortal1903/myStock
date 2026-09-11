import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/viewmodels/base_viewmodel.dart';
import '../../crud/models/lote.dart';
import '../../crud/models/categoria.dart';
import '../../../core/extensions/quantidade_extensions.dart';
import '../../crud/repositories/produto_repository.dart';
import '../../crud/repositories/lote_repository.dart';
import '../../crud/repositories/categoria_repository.dart';
import '../models/item_carrinho.dart';
import '../models/produto_estoque.dart';
import '../repositories/venda_repository.dart';

/// Peso padrão de validade usado no cálculo do lote "Recomendado".
/// (1 - pesoValidade) é aplicado automaticamente ao critério de estoque.
const double kPesoValidadePadrao = 0.65;

/// Chave usada para persistir o peso escolhido pelo usuário em disco.
const String _kPrefsPesoValidade = 'venda_peso_validade';

/// Estende `BaseViewModel` (em vez de `ChangeNotifier` puro) só para herdar
/// a proteção de `safeNotify()` contra "used after dispose" — este
/// ViewModel tem duas operações assíncronas genuinamente independentes e
/// que podem estar em andamento ao mesmo tempo (busca de produtos e
/// finalização da venda), cada uma com seu próprio loading/erro
/// (`buscando`/`erroBusca` e `finalizando`/`erroCarrinho`). Por isso,
/// propositalmente NÃO usa o `status`/`errorMessage`/`run()` compartilhado
/// da base — um único status global colidiria entre as duas operações.
class VendaViewModel extends BaseViewModel {
  final ProdutoRepository   _produtoRepo;
  final LoteRepository      _loteRepo;
  final VendaRepository     _vendaRepo;
  final CategoriaRepository _catRepo;

  VendaViewModel({
    ProdutoRepository?   produtoRepo,
    LoteRepository?      loteRepo,
    VendaRepository?     vendaRepo,
    CategoriaRepository? catRepo,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo    = loteRepo    ?? LoteRepository(),
        _vendaRepo   = vendaRepo   ?? VendaRepository(),
        _catRepo     = catRepo     ?? CategoriaRepository() {
    _loadCategorias();
    _carregarPesoSalvo();
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
      safeNotify();
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

  // ── Ponderação do lote recomendado (Validade x Estoque) ─────────────────────

  double _pesoValidade = kPesoValidadePadrao;

  /// Peso de "validade próxima" no cálculo do lote recomendado (0.0 a 1.0).
  double get pesoValidade => _pesoValidade;

  /// Peso complementar de "menor estoque" (sempre 1 - pesoValidade).
  double get pesoEstoque => 1 - _pesoValidade;

  bool get pesoEhPadrao => (_pesoValidade - kPesoValidadePadrao).abs() < 0.001;

  /// Carrega, se existir, o peso salvo anteriormente pelo usuário.
  /// Falha silenciosamente caso as preferências não possam ser lidas —
  /// nesse caso o valor padrão (kPesoValidadePadrao) continua em uso.
  Future<void> _carregarPesoSalvo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getDouble(_kPrefsPesoValidade);
      if (salvo != null) {
        _pesoValidade = salvo.clamp(0.0, 1.0);
        safeNotify();
      }
    } catch (_) {
      // Preferências indisponíveis; mantém o padrão em memória.
    }
  }

  Future<void> _salvarPeso(double valor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kPrefsPesoValidade, valor);
    } catch (_) {
      // Falha ao persistir; a preferência ainda funciona nesta sessão,
      // mas pode não sobreviver a um reinício do app.
    }
  }

  /// Ajusta a ponderação usada para escolher o lote "Recomendado" e
  /// persiste a escolha em disco para as próximas sessões.
  /// [valor] deve estar entre 0.0 (prioriza só estoque) e 1.0 (prioriza só validade).
  void atualizarPesoValidade(double valor) {
    final novoPeso = valor.clamp(0.0, 1.0);
    if (novoPeso == _pesoValidade) return;
    _pesoValidade = novoPeso;
    safeNotify();
    _salvarPeso(novoPeso);
  }

  void restaurarPesoPadrao() => atualizarPesoValidade(kPesoValidadePadrao);

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
    safeNotify();
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
      safeNotify();
    }
  }

  // ── Carrinho ───────────────────────────────────────────────────────────────
  final List<ItemCarrinho> _carrinho = [];
  List<ItemCarrinho> get carrinho => List.unmodifiable(_carrinho);

  double get totalCarrinho => _carrinho.fold(0, (acc, i) => acc + i.subtotal);
  double get quantidadeItens => _carrinho.fold(0, (acc, i) => acc + i.quantidade);

  String? _erroCarrinho;
  String? get erroCarrinho => _erroCarrinho;

  List<Lote> lotesDisponiveis(ProdutoEstoque item) => item.lotes
      .where((l) => l.status == LoteStatus.ativo && l.quantidade > 0)
      .toList();

  /// Adiciona [quantidade] unidades do [lote] de [item] ao carrinho.
  ///
  /// Para produtos cuja unidade não permite fração (ver
  /// [Produto.permiteFracao] — un, cx, pct), [quantidade] precisa ser um
  /// número inteiro (ex.: 2, não 1.5) — não faz sentido vender "meio
  /// pacote" ou "meia unidade". Para kg/g/L/mL, valores fracionários (ex.:
  /// 1.5, 10.25) são aceitos normalmente.
  Future<void> adicionarAoCarrinho(ProdutoEstoque item, Lote lote, {double quantidade = 1}) async {
    _erroCarrinho = null;
    final produto = item.produto;

    if (quantidade <= 0) {
      _erroCarrinho = 'Informe uma quantidade válida.';
      safeNotify();
      return;
    }

    if (!produto.permiteFracao && !quantidade.isInteiro) {
      _erroCarrinho =
      'A unidade "${produto.unidade}" de "${produto.nome}" não permite quantidade fracionada.';
      safeNotify();
      return;
    }

    final existenteIdx =
    _carrinho.indexWhere((i) => i.produto.id == produto.id && i.lote.id == lote.id);
    final jaNoCarrinho = existenteIdx >= 0 ? _carrinho[existenteIdx].quantidade : 0.0;
    final novaQuantidade = (jaNoCarrinho + quantidade).arredondada;

    if (novaQuantidade > lote.quantidade) {
      _erroCarrinho =
      'Estoque insuficiente para "${produto.nome}" (disponível: ${lote.quantidade.formatada} ${produto.unidade}).';
      safeNotify();
      return;
    }

    if (existenteIdx >= 0) {
      _carrinho[existenteIdx].quantidade = novaQuantidade;
    } else {
      _carrinho.add(ItemCarrinho(
        produto: produto,
        lote: lote,
        quantidade: quantidade.arredondada,
        precoUnitario: lote.precoVenda,
      ));
    }
    safeNotify();
  }

  /// Atualiza a quantidade de [item] já no carrinho. Aplica a mesma regra
  /// de fracionamento de [adicionarAoCarrinho] — unidades como un/cx/pct
  /// só aceitam quantidades inteiras.
  void atualizarQuantidade(ItemCarrinho item, double quantidade) {
    if (quantidade <= 0) {
      removerDoCarrinho(item);
      return;
    }
    final produto = item.produto;
    if (!produto.permiteFracao && !quantidade.isInteiro) {
      _erroCarrinho =
      'A unidade "${produto.unidade}" de "${produto.nome}" não permite quantidade fracionada.';
      safeNotify();
      return;
    }
    if (quantidade > item.lote.quantidade) {
      _erroCarrinho =
      'Estoque insuficiente para "${item.produto.nome}" (disponível: ${item.lote.quantidade.formatada} ${produto.unidade}).';
      safeNotify();
      return;
    }
    item.quantidade = quantidade.arredondada;
    _erroCarrinho = null;
    safeNotify();
  }

  void atualizarPreco(ItemCarrinho item, double preco) {
    item.precoUnitario = preco;
    safeNotify();
  }

  void removerDoCarrinho(ItemCarrinho item) {
    _carrinho.remove(item);
    safeNotify();
  }

  void limparCarrinho() {
    _carrinho.clear();
    _erroCarrinho = null;
    safeNotify();
  }

  // ── Checkout ───────────────────────────────────────────────────────────────
  bool _finalizando = false;
  bool get finalizando => _finalizando;

  Future<int?> finalizarVenda() async {
    if (_carrinho.isEmpty) {
      _erroCarrinho = 'Adicione ao menos um item ao carrinho.';
      safeNotify();
      return null;
    }

    _finalizando = true;
    _erroCarrinho = null;
    safeNotify();

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
      safeNotify();
    }
  }
}