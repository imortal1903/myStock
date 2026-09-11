/// Utilitários para lidar com quantidades de venda/estoque que agora podem
/// ser fracionadas (ex.: 1,5 kg; 10,5 g) para produtos vendidos em unidades
/// como kg/g/L/mL, mas continuam restritas a números inteiros para unidades
/// discretas como un/cx/pct (ver [Produto.permiteFracao]).
library;

extension QuantidadeFormatExtension on num {
  /// Formata a quantidade no padrão brasileiro (vírgula decimal), omitindo
  /// casas decimais quando o valor é inteiro.
  /// Ex.: 1.0 -> '1', 1.5 -> '1,5', 10.25 -> '10,25', 0.500 -> '0,5'.
  String get formatada {
    final d = toDouble();
    if (d == d.roundToDouble()) return d.toStringAsFixed(0);
    var s = d.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }

  /// true se o valor não possui parte fracionária (ex.: 2.0, mas não 2.5).
  bool get isInteiro => toDouble() == toDouble().roundToDouble();

  /// Arredonda para 3 casas decimais — suficiente para vendas fracionadas
  /// (ex.: 1,5 kg; 10,25 g) e evita erros de ponto flutuante acumulados em
  /// somas/subtrações sucessivas no carrinho e no estoque (ex.: 0.1 + 0.2).
  double get arredondada => (toDouble() * 1000).roundToDouble() / 1000;
}

/// Converte um texto digitado pelo usuário — aceitando vírgula OU ponto como
/// separador decimal — em [double]. Retorna `null` se o texto não for um
/// número válido.
double? parseQuantidade(String texto) {
  final normalizado = texto.trim().replaceAll(',', '.');
  if (normalizado.isEmpty) return null;
  return double.tryParse(normalizado);
}