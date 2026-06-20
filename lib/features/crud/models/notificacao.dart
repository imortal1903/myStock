enum NotificacaoTipo { validadeProxima, produtoVencido, estoqueBaixo }

extension NotificacaoTipoExt on NotificacaoTipo {
  String get value {
    switch (this) {
      case NotificacaoTipo.validadeProxima: return 'VALIDADE_PROXIMA';
      case NotificacaoTipo.produtoVencido:  return 'PRODUTO_VENCIDO';
      case NotificacaoTipo.estoqueBaixo:    return 'ESTOQUE_BAIXO';
    }
  }

  static NotificacaoTipo fromString(String s) {
    switch (s) {
      case 'PRODUTO_VENCIDO':  return NotificacaoTipo.produtoVencido;
      case 'ESTOQUE_BAIXO':    return NotificacaoTipo.estoqueBaixo;
      default:                 return NotificacaoTipo.validadeProxima;
    }
  }
}

class Notificacao {
  final int?              id;
  final NotificacaoTipo   tipo;
  final int?              produtoId;
  final int?              loteId;
  final String            mensagem;
  final bool              visualizada;
  final DateTime          criadoEm;

  const Notificacao({
    this.id,
    required this.tipo,
    this.produtoId,
    this.loteId,
    required this.mensagem,
    this.visualizada = false,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'tipo':        tipo.value,
    'produto_id':  produtoId,
    'lote_id':     loteId,
    'mensagem':    mensagem,
    'visualizada': visualizada ? 1 : 0,
    'criado_em':   criadoEm.toIso8601String(),
  };

  factory Notificacao.fromMap(Map<String, dynamic> m) => Notificacao(
    id:          m['id'] as int?,
    tipo:        NotificacaoTipoExt.fromString(m['tipo'] as String),
    produtoId:   m['produto_id'] as int?,
    loteId:      m['lote_id'] as int?,
    mensagem:    m['mensagem'] as String,
    visualizada: (m['visualizada'] as int? ?? 0) == 1,
    criadoEm:    DateTime.parse(m['criado_em'] as String),
  );

  Notificacao copyWith({bool? visualizada}) => Notificacao(
    id:          id,
    tipo:        tipo,
    produtoId:   produtoId,
    loteId:      loteId,
    mensagem:    mensagem,
    visualizada: visualizada ?? this.visualizada,
    criadoEm:    criadoEm,
  );
}