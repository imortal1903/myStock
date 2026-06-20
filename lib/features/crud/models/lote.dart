import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/sqldate_extension.dart';

enum LoteStatus { ativo, vencido, esgotado }

extension LoteStatusExt on LoteStatus {
  String get value {
    switch (this) {
      case LoteStatus.ativo:    return 'ATIVO';
      case LoteStatus.vencido:  return 'VENCIDO';
      case LoteStatus.esgotado: return 'ESGOTADO';
    }
  }

  static LoteStatus fromString(String s) {
    switch (s.toUpperCase()) {
      case 'VENCIDO':  return LoteStatus.vencido;
      case 'ESGOTADO': return LoteStatus.esgotado;
      default:         return LoteStatus.ativo;
    }
  }

  String get label {
    switch (this) {
      case LoteStatus.ativo:    return 'Ativo';
      case LoteStatus.vencido:  return 'Vencido';
      case LoteStatus.esgotado: return 'Esgotado';
    }
  }
}

class Lote {
  final int?       id;
  final int        produtoId;
  final String?    numeroLote;
  final int        quantidade;
  final double?    precoCusto;
  final DateTime?  dataFabricacao;
  final DateTime   dataValidade;
  final DateTime   dataEntrada;
  final LoteStatus status;
  final DateTime   criadoEm;

  const Lote({
    this.id,
    required this.produtoId,
    this.numeroLote,
    required this.quantidade,
    this.precoCusto,
    this.dataFabricacao,
    required this.dataValidade,
    required this.dataEntrada,
    this.status   = LoteStatus.ativo,
    required this.criadoEm,
  });

  // ── SQLite ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'produto_id':      produtoId,
    'numero_lote':     numeroLote,
    'quantidade':      quantidade,
    'preco_custo':     precoCusto,
    'data_fabricacao': dataFabricacao?.toSqlDate,
    'data_validade': dataValidade.toSqlDate,
    'data_entrada': dataEntrada.toSqlDate,
    'status':          status.value,
    'criado_em':       criadoEm.toIso8601String(),
  };

  factory Lote.fromMap(Map<String, dynamic> m) => Lote(
    id:             m['id'] as int?,
    produtoId:      m['produto_id'] as int,
    numeroLote:     m['numero_lote'] as String?,
    quantidade:     m['quantidade'] as int,
    precoCusto:     m['preco_custo'] != null
        ? (m['preco_custo'] as num).toDouble()
        : null,
    dataFabricacao: m['data_fabricacao'] != null
        ? DateTime.parse(m['data_fabricacao'] as String)
        : null,
    dataValidade:   DateTime.parse(m['data_validade'] as String),
    dataEntrada:    DateTime.parse(m['data_entrada'] as String),
    status:         LoteStatusExt.fromString(m['status'] as String? ?? 'ATIVO'),
    criadoEm:       DateTime.parse(m['criado_em'] as String),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get estaVencido =>
      dataValidade.isBeforeDate(DateTime.now());

  int get diasParaVencer =>
      dataValidade.differenceInDays(DateTime.now());

  String get validadeFormatada => _fmt(dataValidade);
  String get entradaFormatada  => _fmt(dataEntrada);
  String? get fabricacaoFormatada =>
      dataFabricacao != null ? _fmt(dataFabricacao!) : null;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

  String get precoCustoFormatado =>
      precoCusto != null ? 'R\$ ${precoCusto!.toStringAsFixed(2)}' : '—';

  Lote copyWith({
    int?       id,
    int?       quantidade,
    double?    precoCusto,
    DateTime?  dataValidade,
    DateTime?  dataFabricacao,
    LoteStatus? status,
    String?    numeroLote,
  }) =>
      Lote(
        id:             id             ?? this.id,
        produtoId:      produtoId,
        numeroLote:     numeroLote     ?? this.numeroLote,
        quantidade:     quantidade     ?? this.quantidade,
        precoCusto:     precoCusto     ?? this.precoCusto,
        dataFabricacao: dataFabricacao ?? this.dataFabricacao,
        dataValidade:   dataValidade   ?? this.dataValidade,
        dataEntrada:    dataEntrada,
        status:         status         ?? this.status,
        criadoEm:       criadoEm,
      );
}