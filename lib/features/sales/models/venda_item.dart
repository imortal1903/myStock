class VendaItem {
  final int? id;
  final int vendaId;
  final int produtoId;
  final int loteId;
  final int quantidade;
  final double precoUnitario;
  final double subtotal;

  const VendaItem({
    this.id,
    required this.vendaId,
    required this.produtoId,
    required this.loteId,
    required this.quantidade,
    required this.precoUnitario,
    required this.subtotal,
  });

  factory VendaItem.fromMap(Map<String, dynamic> map) => VendaItem(
    id: map['id'] as int?,
    vendaId: map['venda_id'] as int,
    produtoId: map['produto_id'] as int,
    loteId: map['lote_id'] as int,
    quantidade: map['quantidade'] as int,
    precoUnitario: (map['preco_unitario'] as num).toDouble(),
    subtotal: (map['subtotal'] as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'venda_id': vendaId,
    'produto_id': produtoId,
    'lote_id': loteId,
    'quantidade': quantidade,
    'preco_unitario': precoUnitario,
    'subtotal': subtotal,
  };
}