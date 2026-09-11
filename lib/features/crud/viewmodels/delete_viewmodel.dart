import '../models/produto.dart';
import '../models/lote.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';
import '../../../core/notificacoes/notificacao_scheduler.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class DeleteViewModel extends BaseViewModel {
  final ProdutoRepository _produtoRepo;
  final LoteRepository _loteRepo;

  DeleteViewModel({
    ProdutoRepository? produtoRepo,
    LoteRepository? loteRepo,
    Produto? initialProduto,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo = loteRepo ?? LoteRepository(),
        abriuComProdutoEspecifico = initialProduto != null {
    loadProdutos();
    if (initialProduto != null) selectProduto(initialProduto);
  }

  /// Verdadeiro quando a tela foi aberta direto para um produto específico.
  final bool abriuComProdutoEspecifico;

  List<Produto> _produtos = [];
  List<Lote> _lotes = [];
  Produto? _selectedProduto;
  String? _lastDeletedNome;

  List<Produto> get produtos => List.unmodifiable(_produtos);
  List<Lote> get lotes => List.unmodifiable(_lotes);
  Produto? get selectedProduto => _selectedProduto;
  String? get lastDeletedNome => _lastDeletedNome;

  Future<void> loadProdutos() async {
    await run<void>(
          () async => _produtos = await _produtoRepo.search(''),
      onError: (e) => 'Erro: $e',
      markSuccess: false,
    );
  }

  Future<void> selectProduto(Produto p) async {
    _selectedProduto = p;
    _lotes = [];
    safeNotify();

    await run<void>(
          () async => _lotes = await _loteRepo.getByProduto(p.id!),
      onError: (e) => 'Erro ao carregar lotes: $e',
      markSuccess: false,
    );
  }

  void clearSelection() {
    _selectedProduto = null;
    _lotes = [];
    safeNotify();
  }

  Future<void> deleteLote(int loteId) async {
    await run<void>(
          () async {
        await _loteRepo.delete(loteId);
        _lotes.removeWhere((l) => l.id == loteId);
        await NotificacaoScheduler.reschedule();
      },
      onError: (e) => 'Erro ao remover lote: $e',
    );
  }

  /// Desativa o produto (soft delete). Os lotes são preservados para não
  /// violar chaves estrangeiras de movimentações/vendas.
  Future<void> deleteProduto(int produtoId) async {
    Produto? target;
    for (final p in _produtos) {
      if (p.id == produtoId) {
        target = p;
        break;
      }
    }
    target ??= _selectedProduto;

    await run<void>(
          () async {
        await _produtoRepo.deactivate(produtoId);
        _lastDeletedNome = target?.nome;
        _produtos.removeWhere((p) => p.id == produtoId);
        _selectedProduto = null;
        _lotes = [];
        await NotificacaoScheduler.reschedule();
      },
      onError: (e) => 'Erro ao remover produto: $e',
    );
  }

  @override
  void resetStatus() {
    _lastDeletedNome = null;
    super.resetStatus();
  }
}