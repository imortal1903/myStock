import '../models/produto.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';
import '../../../core/viewmodels/base_viewmodel.dart';
import 'home_viewmodel.dart' show ProdutoComLotes;

class ProdutoDetailViewModel extends BaseViewModel {
  final ProdutoRepository _produtoRepo;
  final LoteRepository _loteRepo;

  ProdutoDetailViewModel({
    required ProdutoComLotes initial,
    ProdutoRepository? produtoRepo,
    LoteRepository? loteRepo,
  })  : _item = initial,
        _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo = loteRepo ?? LoteRepository();

  ProdutoComLotes _item;
  ProdutoComLotes get item => _item;

  Produto get produto => _item.produto;

  /// Recarrega produto e lotes. Retorna `false` se o produto não existe mais
  /// (ou foi desativado).
  Future<bool> refresh() async {
    try {
      final produto = await _produtoRepo.getById(_item.produto.id!);
      if (produto == null || !produto.ativo) return false;

      final lotes = await _loteRepo.getByProduto(produto.id!);
      _item = ProdutoComLotes(produto: produto, lotes: lotes);
      safeNotify();
      return true;
    } catch (e) {
      setStatus(ViewStatus.error, error: 'Erro ao atualizar: $e');
      return true;
    }
  }
}