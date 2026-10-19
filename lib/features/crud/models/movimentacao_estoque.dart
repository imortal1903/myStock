/// Tipo da movimentação de estoque - mesma semântica da constraint
/// CHECK(tipo IN(...)) da tabela `movimentacoes_estoque`.
enum TipoMovimentacao { entrada, saida, ajuste, perda }

extension TipoMovimentacaoExt on TipoMovimentacao {
  String get value {
    switch (this) {
      case TipoMovimentacao.entrada: return 'ENTRADA';
      case TipoMovimentacao.saida:   return 'SAIDA';
      case TipoMovimentacao.ajuste:  return 'AJUSTE';
      case TipoMovimentacao.perda:   return 'PERDA';
    }
  }

  static TipoMovimentacao fromString(String s) {
    switch (s.toUpperCase()) {
      case 'ENTRADA': return TipoMovimentacao.entrada;
      case 'SAIDA':   return TipoMovimentacao.saida;
      case 'AJUSTE':  return TipoMovimentacao.ajuste;
      case 'PERDA':   return TipoMovimentacao.perda;
      default: throw ArgumentError('Tipo de movimentação inválido: $s');
    }
  }

  String get label {
    switch (this) {
      case TipoMovimentacao.entrada: return 'Entrada';
      case TipoMovimentacao.saida:   return 'Saída';
      case TipoMovimentacao.ajuste:  return 'Ajuste';
      case TipoMovimentacao.perda:   return 'Perda';
    }
  }
}

/// Motivo estruturado da movimentação.
enum MotivoMovimentacao {
  venda,
  vencimento,
  avaria,
  roubo,
  contagemInventario,
  compraFornecedor,
  devolucaoCliente,
  outro,
}

extension MotivoMovimentacaoExt on MotivoMovimentacao {
  String get value {
    switch (this) {
      case MotivoMovimentacao.venda:             return 'VENDA';
      case MotivoMovimentacao.vencimento:         return 'VENCIMENTO';
      case MotivoMovimentacao.avaria:             return 'AVARIA';
      case MotivoMovimentacao.roubo:              return 'ROUBO';
      case MotivoMovimentacao.contagemInventario: return 'CONTAGEM_INVENTARIO';
      case MotivoMovimentacao.compraFornecedor:   return 'COMPRA_FORNECEDOR';
      case MotivoMovimentacao.devolucaoCliente:   return 'DEVOLUCAO_CLIENTE';
      case MotivoMovimentacao.outro:              return 'OUTRO';
    }
  }

  static MotivoMovimentacao? fromString(String? s) {
    if (s == null) return null;
    switch (s.toUpperCase()) {
      case 'VENDA':               return MotivoMovimentacao.venda;
      case 'VENCIMENTO':          return MotivoMovimentacao.vencimento;
      case 'AVARIA':              return MotivoMovimentacao.avaria;
      case 'ROUBO':               return MotivoMovimentacao.roubo;
      case 'CONTAGEM_INVENTARIO': return MotivoMovimentacao.contagemInventario;
      case 'COMPRA_FORNECEDOR':   return MotivoMovimentacao.compraFornecedor;
      case 'DEVOLUCAO_CLIENTE':   return MotivoMovimentacao.devolucaoCliente;
      default:                    return MotivoMovimentacao.outro;
    }
  }

  String get label {
    switch (this) {
      case MotivoMovimentacao.venda:             return 'Venda';
      case MotivoMovimentacao.vencimento:         return 'Vencimento';
      case MotivoMovimentacao.avaria:             return 'Avaria';
      case MotivoMovimentacao.roubo:              return 'Roubo';
      case MotivoMovimentacao.contagemInventario: return 'Contagem de inventário';
      case MotivoMovimentacao.compraFornecedor:   return 'Compra de fornecedor';
      case MotivoMovimentacao.devolucaoCliente:   return 'Devolução de cliente';
      case MotivoMovimentacao.outro:              return 'Outro';
    }
  }
}

class MovimentacaoEstoque {
  final int?               id;
  final int                loteId;
  final TipoMovimentacao   tipo;
  final MotivoMovimentacao? motivo;
  final double              quantidade;
  final String?            observacao;
  final DateTime           criadoEm;

  const MovimentacaoEstoque({
    this.id,
    required this.loteId,
    required this.tipo,
    this.motivo,
    required this.quantidade,
    this.observacao,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'lote_id':    loteId,
    'tipo':       tipo.value,
    'motivo':     motivo?.value,
    'quantidade': quantidade,
    'observacao': observacao,
    'criado_em':  criadoEm.toIso8601String(),
  };

  factory MovimentacaoEstoque.fromMap(Map<String, dynamic> m) => MovimentacaoEstoque(
    id:         m['id'] as int?,
    loteId:     m['lote_id'] as int,
    tipo:       TipoMovimentacaoExt.fromString(m['tipo'] as String),
    motivo:     MotivoMovimentacaoExt.fromString(m['motivo'] as String?),
    quantidade: (m['quantidade'] as num).toDouble(),
    observacao: m['observacao'] as String?,
    criadoEm:   DateTime.parse(m['criado_em'] as String),
  );
}