import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../repositories/categoria_repository.dart';
import '../../../core/validators/produto_validators.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class CategoriaViewModel extends BaseViewModel {
  final CategoriaRepository _repo;

  CategoriaViewModel({CategoriaRepository? repo})
      : _repo = repo ?? CategoriaRepository() {
    loadCategorias();
  }

  final formKey = GlobalKey<FormState>();

  String nome = '';

  List<Categoria> _categorias = [];
  Categoria? _selected;

  List<Categoria> get categorias => List.unmodifiable(_categorias);
  Categoria? get selected => _selected;
  bool get isEditing => _selected != null;

  Future<void> loadCategorias() async {
    await run<void>(
          () async => _categorias = await _repo.getAll(),
      onError: (e) => 'Erro ao carregar categorias: $e',
      markSuccess: false,
    );
  }

  void selectForEdit(Categoria c) {
    _selected = c;
    nome = c.nome;
    setStatus(ViewStatus.idle);
  }

  void startNew() {
    _selected = null;
    nome = '';
    formKey.currentState?.reset();
    setStatus(ViewStatus.idle);
  }

  void cancelEdit() => startNew();

  String? validateNome(String? v) {
    final base = ProdutoValidators.nome(v);
    if (base != null) return base;

    final alvo = v!.trim().toLowerCase();
    final duplicada = _categorias.any(
          (c) => c.id != _selected?.id && c.nome.trim().toLowerCase() == alvo,
    );
    return duplicada ? 'Já existe uma categoria com esse nome' : null;
  }

  Future<bool> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return false;
    formKey.currentState?.save();

    final ok = await run<bool>(
          () async {
        if (_selected == null) {
          await _repo.insert(
            Categoria(nome: nome.trim(), criadoEm: DateTime.now()),
          );
        } else {
          await _repo.update(_selected!.copyWith(nome: nome.trim()));
        }
        _categorias = await _repo.getAll();
        _selected = null;
        nome = '';
        return true;
      },
      onError: (e) => 'Erro ao salvar categoria: $e',
    );

    return ok ?? false;
  }

  /// Remove a categoria. Produtos inativos são desvinculados antes.
  /// Falha se ainda houver produtos ativos vinculados.
  Future<bool> delete(int id) async {
    final ok = await run<bool>(
          () async {
        await _repo.detachInactiveProducts(id);
        await _repo.delete(id);
        _categorias.removeWhere((c) => c.id == id);
        if (_selected?.id == id) {
          _selected = null;
          nome = '';
        }
        return true;
      },
      onError: (_) => 'Não foi possível excluir. Verifique se há produtos '
          'vinculados a esta categoria.',
    );

    return ok ?? false;
  }
}