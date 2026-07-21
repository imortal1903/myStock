import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../repositories/categoria_repository.dart';

enum CategoriaStatus { idle, loading, success, error }

class CategoriaViewModel extends ChangeNotifier {
  final CategoriaRepository _repo;

  CategoriaViewModel({CategoriaRepository? repo})
      : _repo = repo ?? CategoriaRepository() {
    loadCategorias();
  }

  // ── Form key ───────────────────────────────────────────────────────────────

  final formKey = GlobalKey<FormState>();

  // ── Campo do formulário ───────────────────────────────────────────────────

  String nome = '';

  // ── State ──────────────────────────────────────────────────────────────────

  List<Categoria> _categorias = [];
  Categoria?      _selected;
  CategoriaStatus _status = CategoriaStatus.idle;
  String?         _errorMessage;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Categoria> get categorias   => List.unmodifiable(_categorias);
  Categoria?      get selected     => _selected;
  CategoriaStatus get status       => _status;
  String?         get errorMessage => _errorMessage;
  bool            get isLoading    => _status == CategoriaStatus.loading;
  bool            get isEditing    => _selected != null;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadCategorias() async {
    _status = CategoriaStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _categorias = await _repo.getAll();
      _status = CategoriaStatus.idle;
    } catch (e) {
      _status = CategoriaStatus.error;
      _errorMessage = 'Erro ao carregar categorias: $e';
    } finally {
      notifyListeners();
    }
  }

  // ── Preparação do formulário ──────────────────────────────────────────────

  void selectForEdit(Categoria c) {
    _selected = c;
    nome = c.nome;
    _errorMessage = null;
    notifyListeners();
  }

  void startNew() {
    _selected = null;
    nome = '';
    _errorMessage = null;
    formKey.currentState?.reset();
    notifyListeners();
  }

  void cancelEdit() {
    _selected = null;
    nome = '';
    _errorMessage = null;
    notifyListeners();
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? validateNome(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o nome';
    if (v.trim().length < 2) return 'Mínimo 2 caracteres';

    final duplicada = _categorias.any((c) =>
    c.id != _selected?.id &&
        c.nome.trim().toLowerCase() == v.trim().toLowerCase());
    if (duplicada) return 'Já existe uma categoria com esse nome';

    return null;
  }

  // ── Save (insert ou update) ───────────────────────────────────────────────

  Future<bool> save() async {
    final ok = formKey.currentState?.validate() ?? false;
    if (!ok) return false;
    formKey.currentState?.save();

    _status = CategoriaStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_selected == null) {
        final nova = Categoria(nome: nome.trim(), criadoEm: DateTime.now());
        await _repo.insert(nova);
      } else {
        final atualizada = _selected!.copyWith(nome: nome.trim());
        await _repo.update(atualizada);
      }

      await loadCategorias();
      _selected = null;
      nome = '';
      _status = CategoriaStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = CategoriaStatus.error;
      _errorMessage = 'Erro ao salvar categoria: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  // Observação: se "categorias" tiver FK com "produtos" (categoria_id), o
  // delete falha quando houver produtos vinculados. Trate esse erro na UI.

  Future<bool> delete(int id) async {
    _status = CategoriaStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repo.delete(id);
      _categorias.removeWhere((c) => c.id == id);
      if (_selected?.id == id) {
        _selected = null;
        nome = '';
      }
      _status = CategoriaStatus.success;
      return true;
    } catch (e) {
      _status = CategoriaStatus.error;
      _errorMessage = 'Não foi possível excluir. Verifique se há produtos '
          'vinculados a esta categoria.';
      return false;
    } finally {
      notifyListeners();
    }
  }

  void resetStatus() {
    _status = CategoriaStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}