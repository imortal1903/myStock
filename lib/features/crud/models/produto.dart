class Produto {
  final int?   id;
  final String nome;
  final String? descricao;
  final String? codigoBarras;
  final int?   categoriaId;
  final int?   estoqueMin;
  final bool   ativo;
  final String unidade;
  final DateTime criadoEm;

  const Produto({
    this.id,
    required this.nome,
    this.descricao,
    this.codigoBarras,
    this.categoriaId,
    this.estoqueMin,
    this.ativo     = true,
    required this.unidade,
    required this.criadoEm,
  });

  // ── SQLite ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'nome':          nome,
    'descricao':     descricao,
    'codigo_barras': codigoBarras,
    'categoria_id':  categoriaId,
    'estoque_min':   estoqueMin,
    'ativo':         ativo ? 1 : 0,
    'unidade':       unidade,
    'criado_em':     criadoEm.toIso8601String(),
  };

  factory Produto.fromMap(Map<String, dynamic> m) => Produto(
    id:           m['id'] as int?,
    nome:         m['nome'] as String,
    descricao:    m['descricao'] as String?,
    codigoBarras: m['codigo_barras'] as String?,
    categoriaId:  m['categoria_id'] as int?,
    estoqueMin:   m['estoque_min'] as int?,
    ativo:        (m['ativo'] as int? ?? 1) == 1,
    unidade:      m['unidade'] as String,
    criadoEm:     DateTime.parse(m['criado_em'] as String),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get criadoEmFormatado {
    final d = criadoEm;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Produto copyWith({
    int?    id,
    String? nome,
    Object? descricao    = _unset,
    Object? codigoBarras = _unset,
    Object? categoriaId  = _unset,
    Object? estoqueMin   = _unset,
    bool?   ativo,
    String? unidade,
  }) =>
      Produto(
        id:           id     ?? this.id,
        nome:         nome   ?? this.nome,
        descricao:    descricao    == _unset ? this.descricao    : descricao    as String?,
        codigoBarras: codigoBarras == _unset ? this.codigoBarras : codigoBarras as String?,
        categoriaId:  categoriaId  == _unset ? this.categoriaId  : categoriaId  as int?,
        estoqueMin:   estoqueMin   == _unset ? this.estoqueMin   : estoqueMin   as int?,
        ativo:        ativo  ?? this.ativo,
        unidade:      unidade ?? this.unidade,
        criadoEm:     criadoEm,
      );

  static const unidades = ['kg', 'g', 'L', 'mL', 'un', 'cx', 'pct'];

  /// Unidades cuja venda pode ser fracionada (quantidades decimais, ex.:
  /// 1,5 kg ou 10,5 g). Fora desse conjunto (un, cx, pct) a quantidade
  /// vendida/movimentada precisa ser sempre um número inteiro — não existe
  /// "meio pacote" ou "meia unidade".
  static const unidadesFracionaveis = {'kg', 'g', 'L', 'mL'};

  /// true se esta unidade aceita quantidades fracionadas na venda/estoque.
  bool get permiteFracao => unidadesFracionaveis.contains(unidade);
}

const Object _unset = Object();