import 'lote.dart';

/// Combina um [Lote] com os dados do produto ao qual ele pertence, usado
/// em telas que listam lotes fora do contexto de "produto já selecionado"
/// (ex.: seção Atenção do dashboard de Análise, que lista lotes de vários
/// produtos ao mesmo tempo e precisa dizer *qual* produto é cada um).
///
/// Não confundir com ProdutoComLotes (features/crud/viewmodels/
/// home_viewmodel.dart), que é o inverso: um produto com a lista completa
/// dos seus lotes.
class LoteComProduto {
  final Lote lote;
  final String produtoNome;
  final String produtoUnidade;

  const LoteComProduto({
    required this.lote,
    required this.produtoNome,
    required this.produtoUnidade,
  });

  factory LoteComProduto.fromMap(Map<String, dynamic> m) => LoteComProduto(
    lote: Lote.fromMap(m),
    produtoNome: m['produto_nome'] as String,
    produtoUnidade: m['produto_unidade'] as String,
  );
}