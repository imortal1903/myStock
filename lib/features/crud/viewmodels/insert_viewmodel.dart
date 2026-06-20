import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../models/lote.dart';
import '../models/categoria.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';
import '../repositories/categoria_repository.dart';
import '../../../core/notifications/notification_scheduler.dart';
import '../../../core/extensions/date_extensions.dart';

enum InsertStatus { idle, loading, success, error }

class InsertViewModel extends ChangeNotifier {
  final ProdutoRepository  _produtoRepo;
  final LoteRepository     _loteRepo;
  final CategoriaRepository _catRepo;

  InsertViewModel({
    ProdutoRepository?  produtoRepo,
    LoteRepository?     loteRepo,
    CategoriaRepository? catRepo,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo    = loteRepo    ?? LoteRepository(),
        _catRepo     = catRepo     ?? CategoriaRepository() {
    _loadCategorias();
  }

  // ── Form keys ──────────────────────────────────────────────────────────────

  final produtoFormKey = GlobalKey<FormState>();
  final loteFormKey    = GlobalKey<FormState>();

  // ── Produto fields ─────────────────────────────────────────────────────────

  String  nome           = '';
  String  descricao      = '';
  String  codigoBarras   = '';
  String  estoqueMinText = ''; 
  String  unidade        = 'un';
  int?    categoriaId;

  // ── Lote fields ────────────────────────────────────────────────────────────

  String    numeroLote      = '';
  String    quantidadeText  = '';
  String    precoCustoText  = '';
  DateTime? dataFabricacao;
  DateTime? dataValidade;
  DateTime  dataEntrada     = DateTime.now();

  // ── State ──────────────────────────────────────────────────────────────────

  List<Categoria> _categorias = [];
  InsertStatus    _status     = InsertStatus.idle;
  String?         _errorMessage;

  List<Categoria> get categorias    => List.unmodifiable(_categorias);
  InsertStatus    get status        => _status;
  String?         get errorMessage  => _errorMessage;
  bool            get isLoading     => _status == InsertStatus.loading;

  // ── Load categorias ────────────────────────────────────────────────────────

  Future<void> _loadCategorias() async {
    try {
      _categorias = await _catRepo.getAll();
      notifyListeners();
    } catch (_) {}
  }

  // ── Setters ────────────────────────────────────────────────────────────────

  void setUnidade(String u)          { unidade = u; notifyListeners(); }
  void setCategoria(int? id)         { categoriaId = id; notifyListeners(); }
  void setDataValidade(DateTime d)   { dataValidade = d; notifyListeners(); }
  void setDataFabricacao(DateTime d) { dataFabricacao = d; notifyListeners(); }
  void setDataEntrada(DateTime d)    { dataEntrada = d; notifyListeners(); }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? validateNome(String? v) {
    if(v == null || v.trim().isEmpty) return 'Informe o nome';
    if(v.trim().length < 2) return 'Mínimo 2 caracteres';
    return null;
  }

  String? validateEstoqueMin(String? v) {
    if (v != null && v.trim().isNotEmpty) {
      final n = int.tryParse(v.trim());
      if (n == null || n < 0) return 'Valor inválido';
    }
    return null;
  }

  String? validateQuantidade(String? v) {
    if(!temDadosLote) return null;
    if(v == null || v.trim().isEmpty)return 'Informe a quantidade';
    final n = int.tryParse(v.trim());
    if(n == null || n < 0) return 'Quantidade inválida';
    return null;
  }

  String? validatePrecoCusto(String? v) {
    if (v == null || v.trim().isEmpty) return null; 
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Preço inválido';
    return null;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<bool> save() async {
    final produtoOk = produtoFormKey.currentState?.validate() ?? false;

    if (!produtoOk) return false;

    bool loteOk = true;

    if (temDadosLote) {
      loteOk = loteFormKey.currentState?.validate() ?? false;

      if (dataValidade == null) {
        _errorMessage = 'Selecione a data de validade do lote';
        notifyListeners();
        return false;
      }
    }

    if (!loteOk) return false;

    produtoFormKey.currentState?.save();
    loteFormKey.currentState?.save();

    _status = InsertStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // ── Salva produto ─────────────────────────────
      final produtoId = await _produtoRepo.insert(
        Produto(
          nome: nome.trim(),
          descricao: descricao.trim().isEmpty ? null : descricao.trim(),
          codigoBarras: codigoBarras.trim().isEmpty ? null : codigoBarras.trim(),
          estoqueMin: estoqueMinText.trim().isEmpty ? null : int.tryParse(estoqueMinText.trim()),
          categoriaId: categoriaId,
          unidade: unidade,
          criadoEm: DateTime.now(),
        ),
      );

      // ── Salva lote APENAS se preenchido ───────────
      if (temDadosLote) {
        final quantidade = int.tryParse(quantidadeText.trim()) ?? 0;
        
        // CORREÇÃO: Lógica de status consistente com a regra de "vencer amanhã"
        LoteStatus statusLote = LoteStatus.ativo;
        if (dataValidade!.isBeforeDate(DateTime.now())) {
          statusLote = LoteStatus.vencido;
        } else if (quantidade <= 0) {
          statusLote = LoteStatus.esgotado;
        }

        await _loteRepo.insert(
          Lote(
            produtoId: produtoId,
            numeroLote: numeroLote.trim().isEmpty ? null : numeroLote.trim(),
            quantidade: quantidade,
            precoCusto: precoCustoText.trim().isEmpty
                ? null
                : double.parse(precoCustoText.replaceAll(',', '.')),
            dataFabricacao: dataFabricacao,
            dataValidade: dataValidade!,
            dataEntrada: dataEntrada,
            status: statusLote,
            criadoEm: DateTime.now(),
          ),
        );
      }

      await NotificationScheduler.reschedule();

      _status = InsertStatus.success;
      notifyListeners();

      return true;
    } catch (e) {
      _status = InsertStatus.error;
      _errorMessage = 'Erro ao salvar: $e';
      notifyListeners();

      return false;
    }
  }

  void reset() {
    nome = ''; descricao = ''; codigoBarras = ''; estoqueMinText = '';
    unidade = 'un'; categoriaId = null;
    numeroLote = ''; quantidadeText = ''; precoCustoText = '';
    dataFabricacao = null; dataValidade = null;
    dataEntrada = DateTime.now();
    _status = InsertStatus.idle; _errorMessage = null;
    produtoFormKey.currentState?.reset();
    loteFormKey.currentState?.reset();
    notifyListeners();
  }

  bool get temDadosLote {
    return numeroLote.trim().isNotEmpty ||
        quantidadeText.trim().isNotEmpty ||
        precoCustoText.trim().isNotEmpty ||
        dataValidade != null ||
        dataFabricacao != null;
  }
}