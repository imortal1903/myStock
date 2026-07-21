import '../../crud/models/produto.dart';
import '../../crud/models/lote.dart';

class ItemCarrinho {
  final Produto produto;
  final Lote lote;
  int quantidade;
  double precoUnitario;

  ItemCarrinho({
    required this.produto,
    required this.lote,
    required this.quantidade,
    required this.precoUnitario,
  });

  double get subtotal => quantidade * precoUnitario;

  String get subtotalFormatado =>
      'R\$ ${subtotal.toStringAsFixed(2).replaceAll('.', ',')}';

  String get precoUnitarioFormatado =>
      'R\$ ${precoUnitario.toStringAsFixed(2).replaceAll('.', ',')}';
}