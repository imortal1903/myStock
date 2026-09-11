class Venda {
  final int? id;
  final double valorTotal;
  final DateTime criadoEm;

  const Venda({
    this.id,
    required this.valorTotal,
    required this.criadoEm,
  });

  factory Venda.fromMap(Map<String, dynamic> map) => Venda(
    id: map['id'] as int?,
    valorTotal: (map['valor_total'] as num).toDouble(),
    criadoEm: DateTime.parse(map['criado_em'] as String),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'valor_total': valorTotal,
  };

  String get valorTotalFormatado =>
      'R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}';

  String get dataFormatada =>
      '${criadoEm.day.toString().padLeft(2, '0')}/'
          '${criadoEm.month.toString().padLeft(2, '0')}/'
          '${criadoEm.year} '
          '${criadoEm.hour.toString().padLeft(2, '0')}:'
          '${criadoEm.minute.toString().padLeft(2, '0')}';
}