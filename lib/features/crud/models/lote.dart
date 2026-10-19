import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/sqldate_extension.dart';
import '../../../core/extensions/quantidade_extensions.dart';

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

  /// Quantidade em estoque. Para produtos com [Produto.permiteFracao]
  final double     quantidade;

  /// Snapshot imutável da quantidade recebida na criação do lote.
  final double     quantidadeInicial;

  final double     precoCusto;
  final double     precoVenda;
  final DateTime?  dataFabricacao;
  final DateTime   dataValidade;
  final DateTime   dataEntrada;
  final LoteStatus status;

  /// Exclusão lógica do lote (soft delete)
  final bool       ativo;
  final DateTime   criadoEm;

  const Lote({
    this.id,
    required this.produtoId,
    this.numeroLote,
    required this.quantidade,
    required this.quantidadeInicial,
    required this.precoCusto,
    required this.precoVenda,
    this.dataFabricacao,
    required this.dataValidade,
    required this.dataEntrada,
    this.status   = LoteStatus.ativo,
    this.ativo    = true,
    required this.criadoEm,
  });

  /// Cria um lote novo, preenchendo [quantidadeInicial] automaticamente a
  /// partir de [quantidade].
  factory Lote.novo({
    int?       id,
    required int produtoId,
    String?    numeroLote,
    required double quantidade,
    required double precoCusto,
    required double precoVenda,
    DateTime?  dataFabricacao,
    required DateTime dataValidade,
    required DateTime dataEntrada,
    LoteStatus status = LoteStatus.ativo,
    required DateTime criadoEm,
  }) => Lote(
    id:             id,
    produtoId:      produtoId,
    numeroLote:     numeroLote,
    quantidade:     quantidade,
    quantidadeInicial: quantidade,
    precoCusto:     precoCusto,
    precoVenda:     precoVenda,
    dataFabricacao: dataFabricacao,
    dataValidade:   dataValidade,
    dataEntrada:    dataEntrada,
    status:         status,
    criadoEm:       criadoEm,
  );

  // SQLite
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'produto_id':      produtoId,
    'numero_lote':     numeroLote,
    'quantidade':      quantidade,
    'quantidade_inicial': quantidadeInicial,
    'preco_custo':     precoCusto,
    'preco_venda':     precoVenda,
    'data_fabricacao': dataFabricacao?.toSqlDate,
    'data_validade': dataValidade.toSqlDate,
    'data_entrada': dataEntrada.toSqlDate,
    'status':          status.value,
    'ativo':           ativo ? 1 : 0,
    'criado_em':       criadoEm.toIso8601String(),
  };

  factory Lote.fromMap(Map<String, dynamic> m) => Lote(
    id:             m['id'] as int?,
    produtoId:      m['produto_id'] as int,
    numeroLote:     m['numero_lote'] as String?,
    quantidade:     (m['quantidade'] as num).toDouble(),
    quantidadeInicial: (m['quantidade_inicial'] as num?)?.toDouble() ?? (m['quantidade'] as num).toDouble(),
    precoCusto:     (m['preco_custo'] as num).toDouble(),
    precoVenda:     (m['preco_venda'] as num).toDouble(),
    dataFabricacao: m['data_fabricacao'] != null
        ? DateTime.parse(m['data_fabricacao'] as String)
        : null,
    dataValidade:   DateTime.parse(m['data_validade'] as String),
    dataEntrada:    DateTime.parse(m['data_entrada'] as String),
    status:         LoteStatusExt.fromString(m['status'] as String? ?? 'ATIVO'),
    ativo:          (m['ativo'] as int? ?? 1) == 1,
    criadoEm:       DateTime.parse(m['criado_em'] as String),
  );

  // Helpers
  bool get estaVencido =>
      dataValidade.isBeforeDate(DateTime.now());

  int get diasParaVencer =>
      dataValidade.differenceInDays(DateTime.now());

  /// Unidades já consumidas (vendidas, ajustadas ou perdidas) deste lote,
  /// com base no snapshot imutável de criação.
  double get quantidadeVendida =>
      (quantidadeInicial - quantidade).clamp(0.0, quantidadeInicial).arredondada;

  /// Percentual do lote já consumido (0.0 a 1.0). `null` se o lote não
  /// tinha unidades ao ser criado (não deveria ocorrer na prática).
  double? get percentualConsumido =>
      quantidadeInicial == 0 ? null : quantidadeVendida / quantidadeInicial;

  String get validadeFormatada => _fmt(dataValidade);
  String get entradaFormatada  => _fmt(dataEntrada);
  String? get fabricacaoFormatada =>
      dataFabricacao != null ? _fmt(dataFabricacao!) : null;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

  String get precoCustoFormatado => 'R\$ ${precoCusto.toStringAsFixed(2)}';
  String get precoVendaFormatado => 'R\$ ${precoVenda.toStringAsFixed(2)}';

  double? get margemPercentual =>
      precoCusto > 0 ? ((precoVenda - precoCusto) / precoCusto) * 100 : null;

  Lote copyWith({
    int?       id,
    double?    quantidade,
    double?    precoCusto,
    double?    precoVenda,
    DateTime?  dataValidade,
    DateTime?  dataFabricacao,
    DateTime? dataEntrada,
    LoteStatus? status,
    String?    numeroLote,
    bool?      ativo,
  }) =>
      Lote(
        id:             id             ?? this.id,
        produtoId:      produtoId,
        numeroLote:     numeroLote     ?? this.numeroLote,
        quantidade:     quantidade     ?? this.quantidade,
        quantidadeInicial: quantidadeInicial,
        precoCusto:     precoCusto     ?? this.precoCusto,
        precoVenda:     precoVenda     ?? this.precoVenda,
        dataFabricacao: dataFabricacao ?? this.dataFabricacao,
        dataValidade:   dataValidade   ?? this.dataValidade,
        dataEntrada:    dataEntrada ?? this.dataEntrada,
        status:         status         ?? this.status,
        ativo:          ativo          ?? this.ativo,
        criadoEm:       criadoEm,
      );
}