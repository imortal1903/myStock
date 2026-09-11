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
  /// (kg, g, L, mL) pode ser fracionária (ex.: 1.5); para os demais (un,
  /// cx, pct) deve sempre valer um número inteiro — essa regra é aplicada
  /// na camada de UI/ViewModel, não aqui no model.
  final double     quantidade;

  /// Snapshot imutável da quantidade recebida na criação do lote. Nunca é
  /// alterado depois — é o que permite calcular "vendido" (quantidadeInicial
  /// - quantidade) sem depender só do log de movimentações. Use
  /// [Lote.novo] ao criar um lote para garantir que este campo seja
  /// preenchido corretamente.
  final double     quantidadeInicial;

  final double     precoCusto;
  final double     precoVenda;
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
    required this.quantidadeInicial,
    required this.precoCusto,
    required this.precoVenda,
    this.dataFabricacao,
    required this.dataValidade,
    required this.dataEntrada,
    this.status   = LoteStatus.ativo,
    required this.criadoEm,
  });

  /// Cria um lote novo, preenchendo [quantidadeInicial] automaticamente a
  /// partir de [quantidade]. Prefira este construtor em vez de `Lote(...)`
  /// diretamente em qualquer fluxo de cadastro/entrada de lote — evita
  /// esquecer de setar o snapshot inicial.
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

  // ── SQLite ─────────────────────────────────────────────────────────────────

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
    'criado_em':       criadoEm.toIso8601String(),
  };

  factory Lote.fromMap(Map<String, dynamic> m) => Lote(
    id:             m['id'] as int?,
    produtoId:      m['produto_id'] as int,
    numeroLote:     m['numero_lote'] as String?,
    quantidade:     (m['quantidade'] as num).toDouble(),
    // Defensivo: bancos migrados de uma versão anterior à v2 sempre têm a
    // coluna preenchida pelo backfill da migration, mas por segurança caímos
    // para `quantidade` caso o valor venha nulo por algum motivo.
    quantidadeInicial: (m['quantidade_inicial'] as num?)?.toDouble() ?? (m['quantidade'] as num).toDouble(),
    precoCusto:     (m['preco_custo'] as num).toDouble(),
    precoVenda:     (m['preco_venda'] as num).toDouble(),
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

  /// Note: quantidadeInicial propositalmente não é editável aqui — é um
  /// snapshot imutável do momento da criação do lote (veja Lote.novo()).
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
        criadoEm:       criadoEm,
      );
}