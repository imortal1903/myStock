class EstoqueResumo {
  final int quantidadeAtiva;
  final bool temLoteVencido;

  const EstoqueResumo({
    required this.quantidadeAtiva,
    required this.temLoteVencido,
  });

  /// Sem nenhum lote cadastrado ainda.
  static const vazio = EstoqueResumo(quantidadeAtiva: 0, temLoteVencido: false);

  bool get disponivel => quantidadeAtiva > 0;

  /// Sem estoque ativo, mas existe (ou existiu) um lote vencido.
  bool get vencido => quantidadeAtiva == 0 && temLoteVencido;

  /// Sem estoque ativo e sem lote vencido.
  bool get esgotado => quantidadeAtiva == 0 && !temLoteVencido;
}