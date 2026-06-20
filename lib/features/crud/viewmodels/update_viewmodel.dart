import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../models/lote.dart';
import '../models/categoria.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';
import '../repositories/categoria_repository.dart';
import '../../../core/notifications/notification_scheduler.dart';
import '../../../core/extensions/date_extensions.dart';

enum UpdateStatus { idle, loading, success, error }

class UpdateViewModel extends ChangeNotifier {
  final ProdutoRepository   _produtoRepo;
  final LoteRepository      _loteRepo;
  final CategoriaRepository _catRepo;

  UpdateViewModel({
    ProdutoRepository?   produtoRepo,
    LoteRepository?      loteRepo,
    CategoriaRepository? catRepo,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo    = loteRepo    ?? LoteRepository(),
        _catRepo     = catRepo     ?? CategoriaRepository() {
    loadProdutos();
    _loadCategorias();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  final produtoFormKey = GlobalKey<FormState>();
  final loteFormKey    = GlobalKey<FormState>();

  List<Produto>   _produtos    = [];
  List<Categoria> _categorias  = [];
  List<Lote>      _lotes       = [];

  Produto?     _selectedProduto;
  Lote?        _selectedLote;
  UpdateStatus _status        = UpdateStatus.idle;
  String?      _errorMessage;

  // Campos editáveis do produto
  String  editNome           = '';
  String  editDescricao      = '';
  String  editCodigoBarras   = '';
  String  editEstoqueMinText = '';
  String  editUnidade        = 'un';
  int?    editCategoriaId;

  // Campos editáveis do lote
  String    editNumeroLote     = '';
  String    editQuantidadeText = '';
  String    editPrecoCustoText = '';
  DateTime? editDataFabricacao;
  DateTime? editDataValidade;
  DateTime  editDataEntrada    = DateTime.now();
  LoteStatus editStatusLote   = LoteStatus.ativo;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Produto>   get produtos         => List.unmodifiable(_produtos);
  List<Categoria> get categorias       => List.unmodifiable(_categorias);
  List<Lote>      get lotes            => List.unmodifiable(_lotes);
  Produto?        get selectedProduto  => _selectedProduto;
  Lote?           get selectedLote     => _selectedLote;
  UpdateStatus    get status           => _status;
  String?         get errorMessage     => _errorMessage;
  bool            get isLoading        => _status == UpdateStatus.loading;

  static const unidades = ['kg', 'g', 'L', 'mL', 'un', 'cx', 'pct'];

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadProdutos() async {
    _status = UpdateStatus.loading;
    notifyListeners();
    try {
      _produtos = await _produtoRepo.search('');
      _status   = UpdateStatus.idle;
    } catch (e) {
      _status       = UpdateStatus.error;
      _errorMessage = 'Erro ao carregar: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadCategorias() async {
    try {
      _categorias = await _catRepo.getAll();
      notifyListeners();
    } catch (_) {}
  }

  // ── Seleção e Preparação ───────────────────────────────────────────────────

  Future<void> selectProduto(Produto p) async {
    _selectedProduto   = p;
    editNome           = p.nome;
    editDescricao      = p.descricao ?? '';
    editCodigoBarras   = p.codigoBarras ?? '';
    editEstoqueMinText = p.estoqueMin?.toString() ?? '';
    editUnidade        = p.unidade;
    editCategoriaId    = p.categoriaId;

    _lotes = await _loteRepo.getByProduto(p.id!);
    _selectedLote = null;
    _status       = UpdateStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void selectLote(Lote l) {
    _selectedLote      = l;
    editNumeroLote     = l.numeroLote ?? '';
    editQuantidadeText = l.quantidade.toString();
    editPrecoCustoText = l.precoCusto?.toStringAsFixed(2) ?? '';
    editDataFabricacao = l.dataFabricacao;
    editDataValidade   = l.dataValidade;
    editDataEntrada    = l.dataEntrada;
    editStatusLote     = l.status;
    notifyListeners();
  }

  // NOVA FUNÇÃO: Prepara a View para inserir um NOVO lote
  void prepareNewLote() {
    if (_selectedProduto == null) return;

    // Cria um objeto temporário sem ID para representar o novo lote
    _selectedLote = Lote(
      produtoId: _selectedProduto!.id!,
      quantidade: 0,
      dataValidade: DateTime.now(),
      dataEntrada: DateTime.now(),
      criadoEm: DateTime.now(),
    );

    // Limpa os campos de texto
    editNumeroLote     = '';
    editQuantidadeText = '';
    editPrecoCustoText = '';
    editDataFabricacao = null;
    editDataValidade   = null;
    editDataEntrada    = DateTime.now();
    editStatusLote     = LoteStatus.ativo;

    notifyListeners();
  }

  void clearProdutoSelection() {
    _selectedProduto = null;
    _selectedLote    = null;
    _lotes           = [];
    notifyListeners();
  }

  void clearLoteSelection() {
    _selectedLote = null;
    notifyListeners();
  }

  // ── Setters ────────────────────────────────────────────────────────────────

  void setUnidade(String u)              { editUnidade = u; notifyListeners(); }
  void setCategoria(int? id)             { editCategoriaId = id; notifyListeners(); }
  void setDataValidade(DateTime d)       { editDataValidade = d; notifyListeners(); }
  void setDataFabricacao(DateTime d)     { editDataFabricacao = d; notifyListeners(); }
  void setDataEntrada(DateTime d)        { editDataEntrada = d; notifyListeners(); }
  void setStatusLote(LoteStatus s)       { editStatusLote = s; notifyListeners(); }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? validateNome(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o nome';
    return null;
  }

  String? validateQuantidade(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe a quantidade';
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Quantidade inválida';
    return null;
  }

  String? validatePrecoCusto(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Preço inválido';
    return null;
  }

  String? validateEstoqueMin(String? v) {
    if (v != null && v.trim().isNotEmpty) {
      final n = int.tryParse(v.trim());
      if (n == null || n < 0) return 'Valor inválido';
    }
    return null;
  }

  // ── Save Produto ───────────────────────────────────────────────────────────

  Future<void> saveProduto() async {
    if (_selectedProduto == null) return;
    if (!produtoFormKey.currentState!.validate()) return;
    produtoFormKey.currentState!.save();

    _status = UpdateStatus.loading; _errorMessage = null;
    notifyListeners();

    try {
      final updated = _selectedProduto!.copyWith(
        nome:         editNome.trim(),
        descricao:    editDescricao.trim().isEmpty ? null : editDescricao.trim(),
        codigoBarras: editCodigoBarras.trim().isEmpty ? null : editCodigoBarras.trim(),
        estoqueMin:   editEstoqueMinText.trim().isEmpty ? null : int.tryParse(editEstoqueMinText.trim()),
        unidade:      editUnidade,
        categoriaId:  editCategoriaId,
      );
      await _produtoRepo.update(updated);
      _selectedProduto = updated;
      _status = UpdateStatus.success;
    } catch (e) {
      _status = UpdateStatus.error; _errorMessage = 'Erro: $e';
    } finally {
      notifyListeners();
    }
  }

  // ── Save Lote ──────────────────────────────────────────────────────────────

  Future<void> saveLote() async {
    if (_selectedLote == null) return;
    if (!loteFormKey.currentState!.validate()) return;
    if (editDataValidade == null) {
      _errorMessage = 'Selecione a data de validade';
      notifyListeners();
      return;
    }
    loteFormKey.currentState!.save();

    _status = UpdateStatus.loading; _errorMessage = null;
    notifyListeners();

    try {
      final quantidade = int.parse(editQuantidadeText.trim());
      LoteStatus novoStatus;

      // CORREÇÃO: Usa isBeforeDate para que produtos que vencem HOJE não sejam considerados vencidos HOJE.
      if(editDataValidade!.isBeforeDate(DateTime.now())) {
        novoStatus = LoteStatus.vencido;
      } else if(quantidade <= 0) {
        novoStatus = LoteStatus.esgotado;
      } else {
        novoStatus = LoteStatus.ativo;
      }

      // CORREÇÃO: Identifica se é insert (sem ID) ou update (com ID)
      final isNew = _selectedLote!.id == null;

      final updated = _selectedLote!.copyWith(
        numeroLote: editNumeroLote.trim().isEmpty ? null : editNumeroLote.trim(),
        quantidade: quantidade,
        precoCusto: editPrecoCustoText.trim().isEmpty ? null : double.parse(editPrecoCustoText.replaceAll(',', '.')),
        dataFabricacao: editDataFabricacao,
        dataValidade: editDataValidade,
        status: novoStatus,
      );

      if (isNew) {
        final newId = await _loteRepo.insert(updated);
        _lotes.add(updated.copyWith(id: newId));
      } else {
        await _loteRepo.update(updated);
        final idx = _lotes.indexWhere((l) => l.id == updated.id);
        if (idx != -1) _lotes[idx] = updated;
      }

      await NotificationScheduler.reschedule();

      _selectedLote = null;
      _status = UpdateStatus.success;
    } catch (e) {
      _status = UpdateStatus.error; _errorMessage = 'Erro: $e';
    } finally {
      notifyListeners();
    }
  }

  void resetStatus() {
    _status = UpdateStatus.idle;
    notifyListeners();
  }
}