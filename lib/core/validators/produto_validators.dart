import '../extensions/num_parsing_extensions.dart';

/// Validadores compartilhados entre InsertViewModel e UpdateViewModel.
class ProdutoValidators {
  const ProdutoValidators._();

  static String? nome(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o nome';
    if (v.trim().length < 2) return 'Mínimo 2 caracteres';
    return null;
  }

  static String? codigoBarras(String? v, {String? duplicado}) {
    final s = v?.trim() ?? '';
    if (s.isNotEmpty && duplicado != null && s == duplicado) {
      return 'Este código de barras já está cadastrado.';
    }
    return null;
  }

  static String? inteiroOpcional(String? v, {String erro = 'Valor inválido'}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    final n = s.toIntOrNull();
    if (n == null || n < 0) return erro;
    return null;
  }

  /// [permiteFracao] deve refletir `Produto.permiteFracao` da unidade do
  /// produto sendo editado (kg/g/L/mL = true; un/cx/pct = false). Quando
  /// `false`, um valor com parte decimal (ex.: "1,5") é rejeitado — não
  /// existe "meio pacote" ou "meia unidade".
  static String? quantidade(
      String? v, {
        bool obrigatorio = true,
        bool permiteFracao = true,
      }) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return obrigatorio ? 'Informe a quantidade' : null;
    final n = s.toDoubleOrNull();
    if (n == null || n < 0) return 'Quantidade inválida';
    if (!permiteFracao && n != n.roundToDouble()) {
      return 'Esta unidade não permite quantidade fracionada';
    }
    return null;
  }

  static String? preco(
      String? v, {
        bool obrigatorio = true,
        bool maiorQueZero = false,
        String label = 'preço',
      }) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return obrigatorio ? 'Informe o $label' : null;
    final n = s.toDoubleOrNull();
    if (n == null) return 'Preço inválido';
    if (maiorQueZero ? n <= 0 : n < 0) return 'Preço inválido';
    return null;
  }
}