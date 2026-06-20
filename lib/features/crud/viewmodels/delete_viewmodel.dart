import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../models/lote.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';
import '../../../core/notifications/notification_scheduler.dart';

enum DeleteStatus { idle, loading, success, error }

class DeleteViewModel extends ChangeNotifier {
  final ProdutoRepository _produtoRepo;
  final LoteRepository    _loteRepo;

  DeleteViewModel({ProdutoRepository? produtoRepo, LoteRepository? loteRepo})
      : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo    = loteRepo    ?? LoteRepository() {
    loadProdutos();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  List<Produto>  _produtos       = [];
  List<Lote>     _lotes          = [];
  Produto?       _selectedProduto;
  DeleteStatus   _status         = DeleteStatus.idle;
  String?        _errorMessage;
  String?        _lastDeletedNome;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Produto>  get produtos         => List.unmodifiable(_produtos);
  List<Lote>     get lotes            => List.unmodifiable(_lotes);
  Produto?       get selectedProduto  => _selectedProduto;
  DeleteStatus   get status           => _status;
  String?        get errorMessage     => _errorMessage;
  String?        get lastDeletedNome  => _lastDeletedNome;
  bool           get isLoading        => _status == DeleteStatus.loading;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadProdutos() async {
    _status = DeleteStatus.loading; _errorMessage = null;
    notifyListeners();
    try {
      _produtos = await _produtoRepo.search('');
      _status   = DeleteStatus.idle;
    } catch (e) {
      _status = DeleteStatus.error; _errorMessage = 'Erro: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> selectProduto(Produto p) async {
    _selectedProduto = p;
    _lotes = await _loteRepo.getByProduto(p.id!);
    notifyListeners();
  }

  void clearSelection() {
    _selectedProduto = null;
    _lotes = [];
    notifyListeners();
  }

  // ── Delete Lote ────────────────────────────────────────────────────────────

  Future<void> deleteLote(int loteId) async {
    _status = DeleteStatus.loading; _errorMessage = null;
    notifyListeners();
    try {
      await _loteRepo.delete(loteId);
      _lotes.removeWhere((l) => l.id == loteId);
      await NotificationScheduler.reschedule();
      _status = DeleteStatus.success;
    } catch (e) {
      _status = DeleteStatus.error; _errorMessage = 'Erro ao remover lote: $e';
    } finally {
      notifyListeners();
    }
  }

  // ── Delete Produto ─────────────────────────────────────────────────────────

  Future<void> deleteProduto(int produtoId) async {
    final target = _produtos.firstWhere((p) => p.id == produtoId);

    _status = DeleteStatus.loading; _errorMessage = null;
    notifyListeners();
    try {
      // CORREÇÃO: Removido o for-loop que apagava os lotes fisicamente.
      // Como o produto está apenas sendo desativado, forçar a exclusão dos
      // lotes causaria um erro de Foreign Key caso houvesse movimentações ou vendas.
      await _produtoRepo.deactivate(produtoId);

      _lastDeletedNome = target.nome;
      _produtos.removeWhere((p) => p.id == produtoId);
      _selectedProduto = null;
      _lotes = [];

      await NotificationScheduler.reschedule();
      _status = DeleteStatus.success;
    } catch (e) {
      _status = DeleteStatus.error; _errorMessage = 'Erro ao remover produto: $e';
    } finally {
      notifyListeners();
    }
  }

  void resetStatus() {
    _status = DeleteStatus.idle; _errorMessage = null; _lastDeletedNome = null;
    notifyListeners();
  }
}