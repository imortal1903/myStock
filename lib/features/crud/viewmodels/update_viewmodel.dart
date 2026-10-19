import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../models/lote.dart';
import '../models/categoria.dart';
import '../models/estoque_resumo.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';
import '../repositories/categoria_repository.dart';
import '../../../core/notificacoes/notificacao_scheduler.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/num_parsing_extensions.dart';
import '../../../core/extensions/quantidade_extensions.dart';
import '../../../core/validators/produto_validators.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class UpdateViewModel extends BaseViewModel {
  final ProdutoRepository _produtoRepo;
  final LoteRepository _loteRepo;
  final CategoriaRepository _catRepo;

  UpdateViewModel({
    ProdutoRepository? produtoRepo,
    LoteRepository? loteRepo,
    CategoriaRepository? catRepo,
    Produto? initialProduto,
    Lote? initialLote,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo = loteRepo ?? LoteRepository(),
        _catRepo = catRepo ?? CategoriaRepository(),
        abriuComProdutoEspecifico = initialProduto != null,
        abriuComLoteEspecifico = initialLote != null {
    loadProdutos();
    _loadCategorias();
    if (initialProduto != null) {
      // selectProduto é assíncrono (recarrega os lotes do produto); só
      // selecionamos o lote depois dele terminar, para o "voltar" a partir
      // do formulário do lote já cair numa aba "Lotes" com os dados
      // carregados corretamente.
      selectProduto(initialProduto).then((_) {
        if (initialLote != null) selectLote(initialLote);
      });
    }
  }

  /// Verdadeiro quando a tela foi aberta direto para um produto específico.
  final bool abriuComProdutoEspecifico;

  /// Verdadeiro quando a tela foi aberta direto para EDITAR um lote
  /// específico (via `loteInicial`, ao tocar num lote em
  /// ProdutoDetailPage). Usado para decidir, ao salvar o lote com sucesso,
  /// se a tela deve fechar e voltar para ProdutoDetailPage em vez de cair
  /// na visão normal (abas "Dados"/"Lotes") do UpdatePage.
  final bool abriuComLoteEspecifico;

  /// true logo após um saveLote() bem-sucedido — consumido (e resetado)
  /// pela View para decidir se deve fechar a tela em vez de mostrar o
  /// snackbar padrão. Não usar para nada além disso.
  bool _ultimoSaveFoiDeLote = false;
  bool get ultimoSaveFoiDeLote => _ultimoSaveFoiDeLote;
  void limparUltimoSaveFoiDeLote() => _ultimoSaveFoiDeLote = false;

  final produtoFormKey = GlobalKey<FormState>();
  final loteFormKey = GlobalKey<FormState>();

  List<Produto> _produtos = [];
  List<Categoria> _categorias = [];
  List<Lote> _lotes = [];
  Map<int, EstoqueResumo> _estoquePorProduto = {};

  Produto? _selectedProduto;
  Lote? _selectedLote;
  String? _codigoBarrasDuplicado;
  bool _statusLoteManual = false;

  // Campos editáveis
  String editNome = '';
  String editDescricao = '';
  String editCodigoBarras = '';
  String editEstoqueMinText = '';
  String editUnidade = 'un';
  int? editCategoriaId;

  String editNumeroLote = '';
  String editQuantidadeText = '';
  String editPrecoCustoText = '';
  String editPrecoVendaText = '';
  DateTime? editDataFabricacao;
  DateTime? editDataValidade;
  DateTime editDataEntrada = DateTime.now();
  LoteStatus editStatusLote = LoteStatus.ativo;

  // Getters
  List<Produto> get produtos => List.unmodifiable(_produtos);
  List<Categoria> get categorias => List.unmodifiable(_categorias);
  List<Lote> get lotes => List.unmodifiable(_lotes);
  Map<int, EstoqueResumo> get estoquePorProduto => _estoquePorProduto;
  Produto? get selectedProduto => _selectedProduto;
  Lote? get selectedLote => _selectedLote;
  static List<String> get unidades => Produto.unidades;
  bool get permiteFracao => Produto.unidadesFracionaveis.contains(editUnidade);

  EstoqueResumo estoqueDe(Produto p) =>
      _estoquePorProduto[p.id] ?? EstoqueResumo.vazio;

  // Load
  Future<void> loadProdutos() async {
    await run<void>(
          () async {
        await _loteRepo.atualizarStatusVencidos();
        _produtos = await _produtoRepo.search('');
        _estoquePorProduto = await _loteRepo.getResumoEstoquePorProduto();
      },
      onError: (e) => 'Erro ao carregar: $e',
      markSuccess: false,
    );
  }

  Future<void> _loadCategorias() async {
    try {
      _categorias = await _catRepo.getAll();
      safeNotify();
    } catch (_) {
    }
  }

  // Seleção
  Future<void> selectProduto(Produto p) async {
    _selectedProduto = p;
    editNome = p.nome;
    editDescricao = p.descricao ?? '';
    editCodigoBarras = p.codigoBarras ?? '';
    editEstoqueMinText = p.estoqueMin?.toString() ?? '';
    editUnidade = p.unidade;
    editCategoriaId = p.categoriaId;
    _codigoBarrasDuplicado = null;
    _selectedLote = null;
    safeNotify();

    await run<void>(
          () async {
        await _loteRepo.atualizarStatusVencidos();
        _lotes = await _loteRepo.getByProduto(p.id!);
      },
      onError: (e) => 'Erro ao carregar lotes: $e',
      markSuccess: false,
    );
  }

  void selectLote(Lote l) {
    _selectedLote = l;
    editNumeroLote = l.numeroLote ?? '';
    editQuantidadeText =
    permiteFracao ? l.quantidade.formatada : l.quantidade.round().toString();
    editPrecoCustoText = l.precoCusto.toStringAsFixed(2);
    editPrecoVendaText = l.precoVenda.toStringAsFixed(2);
    editDataFabricacao = l.dataFabricacao;
    editDataValidade = l.dataValidade;
    editDataEntrada = l.dataEntrada;
    editStatusLote = l.status;
    _statusLoteManual = false;
    safeNotify();
  }

  void prepareNewLote() {
    final produto = _selectedProduto;
    if (produto == null) return;

    _selectedLote = Lote.novo(
      produtoId: produto.id!,
      quantidade: 0,
      precoCusto: 0,
      precoVenda: 0,
      dataValidade: DateTime.now(),
      dataEntrada: DateTime.now(),
      criadoEm: DateTime.now(),
    );

    editNumeroLote = '';
    editQuantidadeText = '';
    editPrecoCustoText = '';
    editPrecoVendaText = '';
    editDataFabricacao = null;
    editDataValidade = null;
    editDataEntrada = DateTime.now();
    editStatusLote = LoteStatus.ativo;
    _statusLoteManual = false;
    safeNotify();
  }

  void clearProdutoSelection() {
    _selectedProduto = null;
    _selectedLote = null;
    _lotes = [];
    safeNotify();
  }

  void clearLoteSelection() {
    _selectedLote = null;
    safeNotify();
  }

  // Setters
  void setUnidade(String u) {
    editUnidade = u;
    safeNotify();
    if (!permiteFracao) _arredondarLotesParaBaixo();
  }

  /// Quando a unidade deixa de permitir fração, qualquer
  /// quantidade fracionária dos lotes já carregados desse produto deixa de
  /// fazer sentido, "1,5 un" não existe. Arredonda para baixo.
  Future<void> _arredondarLotesParaBaixo() async {
    final alterados = <Lote>[];

    for (var i = 0; i < _lotes.length; i++) {
      final l = _lotes[i];
      final piso = l.quantidade.floorToDouble();
      if (piso != l.quantidade) {
        final atualizado = l.copyWith(quantidade: piso);
        _lotes[i] = atualizado;
        alterados.add(atualizado);
      }
    }

    final loteSelecionado = _selectedLote;
    if (loteSelecionado != null) {
      final piso = loteSelecionado.quantidade.floorToDouble();
      if (piso != loteSelecionado.quantidade) {
        _selectedLote = loteSelecionado.copyWith(quantidade: piso);
        editQuantidadeText = piso.round().toString();
      }
    }

    if (alterados.isEmpty) {
      safeNotify();
      return;
    }

    safeNotify();

    try {
      for (final l in alterados) {
        await _loteRepo.update(l);
      }
      _estoquePorProduto = await _loteRepo.getResumoEstoquePorProduto();
      safeNotify();
    } catch (_) {
    }
  }

  void setCategoria(int? id) {
    editCategoriaId = id;
    safeNotify();
  }

  void setDataValidade(DateTime d) {
    editDataValidade = d;
    safeNotify();
  }

  void setDataFabricacao(DateTime d) {
    editDataFabricacao = d;
    safeNotify();
  }

  void setDataEntrada(DateTime d) {
    editDataEntrada = d;
    safeNotify();
  }

  void setStatusLote(LoteStatus s) {
    editStatusLote = s;
    _statusLoteManual = true;
    safeNotify();
  }

  /// Status sugerido a partir de quantidade/validade.
  LoteStatus get statusSugerido {
    final qtd = editQuantidadeText.toDoubleOrZero();
    if (qtd <= 0) return LoteStatus.esgotado;
    if (editDataValidade?.isBeforeDate(DateTime.now()) ?? false) {
      return LoteStatus.vencido;
    }
    return LoteStatus.ativo;
  }

  // Validators
  String? validateNome(String? v) => ProdutoValidators.nome(v);

  String? validateCodigoBarras(String? v) => ProdutoValidators.codigoBarras(
    v,
    duplicado: _codigoBarrasDuplicado,
  );

  String? validateEstoqueMin(String? v) =>
      ProdutoValidators.inteiroOpcional(v);

  String? validateQuantidade(String? v) =>
      ProdutoValidators.quantidade(v, permiteFracao: permiteFracao);

  String? validatePrecoCusto(String? v) =>
      ProdutoValidators.preco(v, label: 'preço de custo');

  String? validatePrecoVenda(String? v) => ProdutoValidators.preco(
    v,
    label: 'preço de venda',
    maiorQueZero: true,
  );

  // Save produto
  Future<void> saveProduto() async {
    final produto = _selectedProduto;
    if (produto == null) return;
    _ultimoSaveFoiDeLote = false;

    final codigo = editCodigoBarras.trim();
    _codigoBarrasDuplicado = null;
    if (codigo.isNotEmpty &&
        await _produtoRepo.existsCodigoBarras(codigo,
            excludeId: produto.id)) {
      _codigoBarrasDuplicado = codigo;
    }

    if (!(produtoFormKey.currentState?.validate() ?? false)) {
      safeNotify();
      return;
    }
    produtoFormKey.currentState?.save();

    await run<void>(
          () async {
        final updated = produto.copyWith(
          nome: editNome.trim(),
          descricao: editDescricao.nullIfEmpty,
          codigoBarras: editCodigoBarras.nullIfEmpty,
          estoqueMin: editEstoqueMinText.toIntOrNull(),
          unidade: editUnidade,
          categoriaId: editCategoriaId,
        );
        await _produtoRepo.update(updated);
        _selectedProduto = updated;

        final idx = _produtos.indexWhere((p) => p.id == updated.id);
        if (idx != -1) _produtos[idx] = updated;
      },
      onError: (e) {
        if (e is CodigoBarrasDuplicadoException) {
          _codigoBarrasDuplicado = e.codigoBarras;
          produtoFormKey.currentState?.validate();
          return 'Já existe um produto com esse código de barras';
        }
        return 'Erro: $e';
      },
    );
  }

  // Save lote
  Future<void> saveLote() async {
    final lote = _selectedLote;
    if (lote == null) return;
    if (!(loteFormKey.currentState?.validate() ?? false)) return;

    if (editDataValidade == null) {
      setStatus(ViewStatus.error, error: 'Selecione a data de validade');
      return;
    }
    loteFormKey.currentState?.save();

    await run<void>(() async {
        final quantidade = permiteFracao
            ? editQuantidadeText.toDoubleOrZero()
            : editQuantidadeText.toDoubleOrZero().roundToDouble();

        final novoStatus = _statusLoteManual ? editStatusLote : statusSugerido;

        final isNew = lote.id == null;
        final Lote updated;
        if (isNew) {
          updated = Lote.novo(
            produtoId: lote.produtoId,
            numeroLote: editNumeroLote.nullIfEmpty,
            quantidade: quantidade,
            precoCusto: editPrecoCustoText.toDoubleOrZero(),
            precoVenda: editPrecoVendaText.toDoubleOrZero(),
            dataFabricacao: editDataFabricacao,
            dataValidade: editDataValidade!,
            dataEntrada: editDataEntrada,
            status: novoStatus,
            criadoEm: DateTime.now(),
          );
        } else {
          updated = lote.copyWith(
            numeroLote: editNumeroLote.nullIfEmpty,
            quantidade: quantidade,
            precoCusto: editPrecoCustoText.toDoubleOrZero(),
            precoVenda: editPrecoVendaText.toDoubleOrZero(),
            dataFabricacao: editDataFabricacao,
            dataValidade: editDataValidade,
            dataEntrada: editDataEntrada,
            status: novoStatus,
          );
        }

        if (isNew) {
          final newId = await _loteRepo.insert(updated);
          _lotes.add(updated.copyWith(id: newId));
        } else {
          await _loteRepo.update(updated);
          final idx = _lotes.indexWhere((l) => l.id == updated.id);
          if (idx != -1) _lotes[idx] = updated;
        }

        await NotificacaoScheduler.reschedule();
        _estoquePorProduto = await _loteRepo.getResumoEstoquePorProduto();
        _selectedLote = null;
        _statusLoteManual = false;
        _ultimoSaveFoiDeLote = true;
      },
      onError: (e) => 'Erro: $e',
    );
  }
}