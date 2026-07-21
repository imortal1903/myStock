import '../../crud/models/produto.dart';
import '../../crud/models/lote.dart';

/// Resumo do estoque de um produto para exibição na tela de vendas.
class ProdutoEstoque {
  final Produto produto;
  final List<Lote> lotes;

  const ProdutoEstoque({required this.produto, required this.lotes});

  /// Soma da quantidade de todos os lotes ATIVOS (não vencidos, não esgotados).
  int get quantidadeDisponivel =>
      lotes.where((l) => l.status == LoteStatus.ativo).fold(0, (acc, l) => acc + l.quantidade);

  bool get disponivelParaVenda => quantidadeDisponivel > 0;

  /// Sem estoque ativo, mas existe lote vencido — prioriza esse aviso.
  bool get vencido =>
      quantidadeDisponivel == 0 && lotes.any((l) => l.status == LoteStatus.vencido);

  /// Sem estoque ativo e sem lote vencido (esgotado ou nunca teve lote).
  bool get esgotado => quantidadeDisponivel == 0 && !vencido;
}