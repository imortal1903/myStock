class Categoria{
  final int?   id;
  final String nome;
  final DateTime criadoEm;

  const Categoria({
    this.id,
    required this.nome,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'nome':      nome,
    'criado_em': criadoEm.toIso8601String(),
  };

  factory Categoria.fromMap(Map<String, dynamic> m) => Categoria(
    id:       m['id'] as int?,
    nome:     m['nome'] as String,
    criadoEm: DateTime.parse(m['criado_em'] as String),
  );

  Categoria copyWith({int? id, String? nome}) => Categoria(
    id:       id       ?? this.id,
    nome:     nome     ?? this.nome,
    criadoEm: criadoEm,
  );
}