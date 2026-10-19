import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../models/lote.dart';
import '../models/categoria.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';
import '../repositories/categoria_repository.dart';
import '../../../core/notificacoes/notificacao_scheduler.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/num_parsing_extensions.dart';
import '../../../core/validators/produto_validators.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class InsertViewModel extends BaseViewModel {
  final ProdutoRepository _produtoRepo;
  final LoteRepository _loteRepo;
  final CategoriaRepository _catRepo;

  InsertViewModel({
    ProdutoRepository? produtoRepo,
    LoteRepository? loteRepo,
    CategoriaRepository? catRepo,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo = loteRepo ?? LoteRepository(),
        _catRepo = catRepo ?? CategoriaRepository() {
    _loadCategorias();
  }

  //  keys
  final produtoFormKey = GlobalKey<FormState>();
  final loteFormKey = GlobalKey<FormState>();

  // Produto
  String nome = '';
  String descricao = '';
  String codigoBarras = '';
  String estoqueMinText = '';
  String unidade = 'un';
  int? categoriaId;

  // Lote
  String numeroLote = '';
  String quantidadeText = '';
  String precoCustoText = '';
  String precoVendaText = '';
  DateTime? dataFabricacao;
  DateTime? dataValidade;
  DateTime dataEntrada = DateTime.now();

  List<Categoria> _categorias = [];
  String? _codigoBarrasDuplicado;

  List<Categoria> get categorias => List.unmodifiable(_categorias);

  Future<void> _loadCategorias() async {
    try {
      _categorias = await _catRepo.getAll();
      safeNotify();
    } catch (_) {
    }
  }

  // Setters produto
  void setUnidade(String u) {
    unidade = u;
    safeNotify();
  }

  void setCategoria(int? id) {
    categoriaId = id;
    safeNotify();
  }

  void setCodigoBarras(String v) {
    codigoBarras = v;
    safeNotify();
  }

  // Setters lote (mantêm temDadosLote sempre atualizado)
  void setNumeroLote(String v) => _updateLoteField(() => numeroLote = v);
  void setQuantidade(String v) => _updateLoteField(() => quantidadeText = v);
  void setPrecoCusto(String v) => _updateLoteField(() => precoCustoText = v);
  void setPrecoVenda(String v) => _updateLoteField(() => precoVendaText = v);

  void setDataValidade(DateTime d) => _updateLoteField(() => dataValidade = d);
  void setDataFabricacao(DateTime d) =>
      _updateLoteField(() => dataFabricacao = d);

  void setDataEntrada(DateTime d) {
    dataEntrada = d;
    safeNotify();
  }

  bool _tentouSalvarLote = false;

  void _updateLoteField(VoidCallback apply) {
    final antes = temDadosLote;
    apply();
    if (_tentouSalvarLote || (antes && !temDadosLote)) {
      loteFormKey.currentState?.validate();
    }
    safeNotify();
  }

  bool get temDadosLote =>
      numeroLote.trim().isNotEmpty ||
          quantidadeText.trim().isNotEmpty ||
          precoCustoText.trim().isNotEmpty ||
          precoVendaText.trim().isNotEmpty ||
          dataValidade != null ||
          dataFabricacao != null;

  // Validators
  String? validateNome(String? v) => ProdutoValidators.nome(v);

  String? validateCodigoBarras(String? v) =>
      ProdutoValidators.codigoBarras(v, duplicado: _codigoBarrasDuplicado);

  String? validateEstoqueMin(String? v) =>
      ProdutoValidators.inteiroOpcional(v);

  String? validateQuantidade(String? v) =>
      temDadosLote ? ProdutoValidators.quantidade(v) : null;

  String? validatePrecoCusto(String? v) => temDadosLote
      ? ProdutoValidators.preco(v, label: 'preço de custo')
      : null;

  String? validatePrecoVenda(String? v) => temDadosLote
      ? ProdutoValidators.preco(v,
      label: 'preço de venda', maiorQueZero: true)
      : null;

  // Save
  Future<bool> save() async {
    final codigo = codigoBarras.trim();
    _codigoBarrasDuplicado = null;
    if (codigo.isNotEmpty && await _produtoRepo.existsCodigoBarras(codigo)) {
      _codigoBarrasDuplicado = codigo;
    }

    if (!(produtoFormKey.currentState?.validate() ?? false)) return false;

    if (temDadosLote) {
      _tentouSalvarLote = true;
      if (!(loteFormKey.currentState?.validate() ?? false)) return false;
      if (dataValidade == null) {
        setStatus(ViewStatus.error,
            error: 'Selecione a data de validade do lote');
        return false;
      }
    }

    produtoFormKey.currentState?.save();
    loteFormKey.currentState?.save();

    final ok = await run<bool>(
          () async {
        final produtoId = await _produtoRepo.insert(
          Produto(
            nome: nome.trim(),
            descricao: descricao.nullIfEmpty,
            codigoBarras: codigoBarras.nullIfEmpty,
            estoqueMin: estoqueMinText.toIntOrNull(),
            categoriaId: categoriaId,
            unidade: unidade,
            criadoEm: DateTime.now(),
          ),
        );

        if (temDadosLote) {
          final quantidade = quantidadeText.toDoubleOrZero();

          final statusLote = dataValidade!.isBeforeDate(DateTime.now())
              ? LoteStatus.vencido
              : (quantidade <= 0 ? LoteStatus.esgotado : LoteStatus.ativo);

          await _loteRepo.insert(
            Lote.novo(
              produtoId: produtoId,
              numeroLote: numeroLote.nullIfEmpty,
              quantidade: quantidade,
              precoCusto: precoCustoText.toDoubleOrZero(),
              precoVenda: precoVendaText.toDoubleOrZero(),
              dataFabricacao: dataFabricacao,
              dataValidade: dataValidade!,
              dataEntrada: dataEntrada,
              status: statusLote,
              criadoEm: DateTime.now(),
            ),
          );
        }

        await NotificacaoScheduler.reschedule();
        return true;
      },
      onError: (e) {
        if (e is CodigoBarrasDuplicadoException) {
          _codigoBarrasDuplicado = e.codigoBarras;
          produtoFormKey.currentState?.validate();
          return 'Este código de barras já está cadastrado.';
        }
        return 'Erro ao salvar: $e';
      },
    );

    return ok ?? false;
  }

  void reset() {
    nome = '';
    descricao = '';
    codigoBarras = '';
    estoqueMinText = '';
    unidade = 'un';
    categoriaId = null;
    numeroLote = '';
    quantidadeText = '';
    precoCustoText = '';
    precoVendaText = '';
    dataFabricacao = null;
    dataValidade = null;
    dataEntrada = DateTime.now();
    _codigoBarrasDuplicado = null;
    _tentouSalvarLote = false;
    produtoFormKey.currentState?.reset();
    loteFormKey.currentState?.reset();
    setStatus(ViewStatus.idle);
  }
}