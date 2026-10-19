import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/database/db.dart';
import '../../../features/crud/models/movimentacao_estoque.dart';
import '../../analise/services/previsao_estoque_service.dart';

enum FormatoExportacao { csv, pdf }
// Catálogo: colunas, seções (tabelas) e modelos

/// Uma informação (coluna) de uma tabela do relatório.
class ColunaRelatorio {
  final String id;
  final String titulo;

  /// Vem marcada por padrão ao escolher a seção.
  final bool padrao;

  /// Alinha à direita no PDF.
  final bool numerica;

  const ColunaRelatorio(
      this.id,
      this.titulo, {
        this.padrao = true,
        this.numerica = false,
      });
}

/// Cada tabela que pode entrar no relatório (um checkbox na tela).
enum SecaoRelatorio {
  posicaoEstoque(
    titulo: 'Posição de estoque',
    descricao: 'Quantidade, custo, preço e valor em estoque de cada produto',
    colunas: [
      ColunaRelatorio('produto', 'Produto'),
      ColunaRelatorio('categoria', 'Categoria'),
      ColunaRelatorio('codigo', 'Código de barras', padrao: false),
      ColunaRelatorio('unidade', 'Unidade'),
      ColunaRelatorio('quantidade', 'Quantidade', numerica: true),
      ColunaRelatorio('custo_medio', 'Custo médio (R\$)', numerica: true),
      ColunaRelatorio('preco_medio', 'Preço de venda médio (R\$)',
          numerica: true),
      ColunaRelatorio('valor_custo', 'Valor em estoque (R\$)', numerica: true),
      ColunaRelatorio('valor_venda', 'Valor potencial de venda (R\$)',
          numerica: true, padrao: false),
    ],
  ),
  validade(
    titulo: 'Validade (lotes vencidos e a vencer)',
    descricao: 'Lotes com estoque que já venceram ou vencem em breve',
    usaValidade: true,
    colunas: [
      ColunaRelatorio('produto', 'Produto'),
      ColunaRelatorio('lote', 'Lote'),
      ColunaRelatorio('validade', 'Validade'),
      ColunaRelatorio('dias', 'Dias para vencer', numerica: true),
      ColunaRelatorio('situacao', 'Situação'),
      ColunaRelatorio('quantidade', 'Quantidade', numerica: true),
      ColunaRelatorio('unidade', 'Unidade'),
      ColunaRelatorio('risco_custo', 'Valor em risco - custo (R\$)',
          numerica: true),
      ColunaRelatorio('risco_venda', 'Valor em risco - venda (R\$)',
          numerica: true, padrao: false),
    ],
  ),
  perdas(
    titulo: 'Perdas registradas',
    descricao: 'Baixas por vencimento, avaria, roubo etc. no período',
    usaPeriodo: true,
    colunas: [
      ColunaRelatorio('data', 'Data'),
      ColunaRelatorio('produto', 'Produto'),
      ColunaRelatorio('lote', 'Lote'),
      ColunaRelatorio('motivo', 'Motivo'),
      ColunaRelatorio('quantidade', 'Quantidade', numerica: true),
      ColunaRelatorio('unidade', 'Unidade'),
      ColunaRelatorio('valor', 'Valor perdido (R\$)', numerica: true),
      ColunaRelatorio('observacao', 'Observação', padrao: false),
    ],
  ),
  vendas(
    titulo: 'Vendas',
    descricao: 'Uma linha por venda: código, data, produtos, receita e lucro',
    usaPeriodo: true,
    colunas: [
      ColunaRelatorio('codigo', 'Código da venda'),
      ColunaRelatorio('data', 'Data'),
      ColunaRelatorio('produtos', 'Produtos'),
      ColunaRelatorio('receita', 'Receita (R\$)', numerica: true),
      ColunaRelatorio('lucro', 'Lucro (R\$)', numerica: true),
      ColunaRelatorio('margem', 'Margem', numerica: true, padrao: false),
    ],
  ),
  maisVendidos(
    titulo: 'Mais vendidos (por quantidade)',
    descricao: 'Top 10 produtos por quantidade vendida no período',
    usaPeriodo: true,
    colunas: [
      ColunaRelatorio('pos', '#', numerica: true),
      ColunaRelatorio('produto', 'Produto'),
      ColunaRelatorio('unidade', 'Unidade'),
      ColunaRelatorio('quantidade', 'Quantidade vendida', numerica: true),
      ColunaRelatorio('receita', 'Receita (R\$)', numerica: true),
      ColunaRelatorio('lucro', 'Lucro (R\$)', numerica: true),
      ColunaRelatorio('margem', 'Margem', numerica: true, padrao: false),
    ],
  ),
  maisLucrativos(
    titulo: 'Mais lucrativos (por lucro)',
    descricao: 'Top 10 produtos por lucro no período',
    usaPeriodo: true,
    colunas: [
      ColunaRelatorio('pos', '#', numerica: true),
      ColunaRelatorio('produto', 'Produto'),
      ColunaRelatorio('unidade', 'Unidade'),
      ColunaRelatorio('quantidade', 'Quantidade vendida', numerica: true),
      ColunaRelatorio('receita', 'Receita (R\$)', numerica: true),
      ColunaRelatorio('lucro', 'Lucro (R\$)', numerica: true),
      ColunaRelatorio('margem', 'Margem', numerica: true, padrao: false),
    ],
  ),
  baixoGiro(
    titulo: 'Baixo giro',
    descricao: 'Produtos com estoque parado: venderam pouco frente ao estoque',
    usaPeriodo: true,
    colunas: [
      ColunaRelatorio('produto', 'Produto'),
      ColunaRelatorio('categoria', 'Categoria', padrao: false),
      ColunaRelatorio('unidade', 'Unidade'),
      ColunaRelatorio('estoque', 'Estoque atual', numerica: true),
      ColunaRelatorio('vendido', 'Vendido no período', numerica: true),
      ColunaRelatorio('giro', 'Giro (% do estoque vendido)', numerica: true),
      ColunaRelatorio('valor_parado', 'Valor parado - custo (R\$)',
          numerica: true),
    ],
  ),
  reposicao(
    titulo: 'Reposição sugerida',
    descricao: 'Produtos com estoque abaixo do necessário e quanto comprar',
    usaCobertura: true,
    colunas: [
      ColunaRelatorio('produto', 'Produto'),
      ColunaRelatorio('unidade', 'Unidade'),
      ColunaRelatorio('estoque', 'Estoque atual', numerica: true),
      ColunaRelatorio('media_semana', 'Média por semana (MMS)',
          numerica: true),
      ColunaRelatorio('base', 'Base da média'),
      ColunaRelatorio('cobertura', 'Cobertura atual (dias)', numerica: true),
      ColunaRelatorio('minimo', 'Estoque mínimo',
          numerica: true, padrao: false),
      ColunaRelatorio('necessario', 'Estoque necessário', numerica: true),
      ColunaRelatorio('sugerido', 'Sugestão de compra', numerica: true),
      ColunaRelatorio('custo', 'Custo estimado (R\$)', numerica: true),
    ],
  ),
  movimentacoes(
    titulo: 'Movimentações de estoque',
    descricao: 'Entradas, saídas, ajustes e perdas, com data e motivo',
    usaPeriodo: true,
    colunas: [
      ColunaRelatorio('data', 'Data'),
      ColunaRelatorio('produto', 'Produto'),
      ColunaRelatorio('lote', 'Lote'),
      ColunaRelatorio('tipo', 'Tipo'),
      ColunaRelatorio('motivo', 'Motivo'),
      ColunaRelatorio('quantidade', 'Quantidade', numerica: true),
      ColunaRelatorio('unidade', 'Unidade', padrao: false),
      ColunaRelatorio('observacao', 'Observação'),
    ],
  );

  final String titulo;
  final String descricao;
  final List<ColunaRelatorio> colunas;
  final bool usaPeriodo;
  final bool usaValidade;
  final bool usaCobertura;

  const SecaoRelatorio({
    required this.titulo,
    required this.descricao,
    required this.colunas,
    this.usaPeriodo = false,
    this.usaValidade = false,
    this.usaCobertura = false,
  });
}

/// Modelos prontos: cada um só marca as seções certas (com as colunas
/// padrão).
enum ModeloRelatorio {
  posicaoEstoque(
    titulo: 'Posição de estoque',
    arquivo: 'posicao_estoque',
    oQueMostra: 'Produtos, categoria, quantidade total, custo, preço de '
        'venda e valor total em estoque',
    paraQueServe: 'Saber quanto há parado em mercadoria',
    secoes: [SecaoRelatorio.posicaoEstoque],
  ),
  validadePerdas(
    titulo: 'Validade e perdas',
    arquivo: 'validade_perdas',
    oQueMostra: 'Lotes vencidos e a vencer (7, 15 ou 30 dias), quantidade '
        'e valor em risco, mais as perdas já registradas',
    paraQueServe: 'Agir antes de perder o produto',
    secoes: [SecaoRelatorio.validade, SecaoRelatorio.perdas],
  ),
  vendasPorPeriodo(
    titulo: 'Vendas por período',
    arquivo: 'vendas',
    oQueMostra: 'Código da venda, data, produtos, receita, lucro e total '
        'do período',
    paraQueServe: 'Acompanhar o faturamento',
    secoes: [SecaoRelatorio.vendas],
  ),
  maisMenosVendidos(
    titulo: 'Produtos mais e menos vendidos',
    arquivo: 'ranking_produtos',
    oQueMostra: 'Ranking por quantidade e por lucro, mais os produtos de '
        'baixo giro',
    paraQueServe: 'Decidir compras e promoções',
    secoes: [
      SecaoRelatorio.maisVendidos,
      SecaoRelatorio.maisLucrativos,
      SecaoRelatorio.baixoGiro,
    ],
  ),
  reposicaoSugerida(
    titulo: 'Reposição sugerida',
    arquivo: 'reposicao',
    oQueMostra: 'Produtos com estoque abaixo do necessário, com base nas '
        'vendas recentes',
    paraQueServe: 'Saber o que comprar',
    secoes: [SecaoRelatorio.reposicao],
  ),
  movimentacoesEstoque(
    titulo: 'Movimentações de estoque',
    arquivo: 'movimentacoes',
    oQueMostra: 'Entradas, saídas e ajustes com data e motivo',
    paraQueServe: 'Auditoria e conferência',
    secoes: [SecaoRelatorio.movimentacoes],
  );

  final String titulo;
  final String arquivo;
  final String oQueMostra;
  final String paraQueServe;
  final List<SecaoRelatorio> secoes;

  const ModeloRelatorio({
    required this.titulo,
    required this.arquivo,
    required this.oQueMostra,
    required this.paraQueServe,
    required this.secoes,
  });
}

// Entrada e saída do serviço
/// Intervalo [desde, ate) usado nas seções que dependem de período.
class PeriodoRelatorio {
  final DateTime desde;
  final DateTime ate;
  final String rotulo;

  const PeriodoRelatorio(this.desde, this.ate, this.rotulo);

  bool contem(DateTime d) => !d.isBefore(desde) && d.isBefore(ate);
}

class ConfigRelatorio {
  final String titulo;
  final String arquivo;
  final FormatoExportacao formato;

  final Map<SecaoRelatorio, Set<String>> selecao;
  final PeriodoRelatorio periodo;
  final int diasValidade;
  final int diasCobertura;

  const ConfigRelatorio({
    required this.titulo,
    required this.arquivo,
    required this.formato,
    required this.selecao,
    required this.periodo,
    required this.diasValidade,
    required this.diasCobertura,
  });
}

/// Uma tabela já calculada: todas as colunas da seção, em texto.
class TabelaRelatorio {
  final SecaoRelatorio secao;
  final List<Map<String, String>> linhas;
  final Map<String, String> totais;
  final String? observacao;

  const TabelaRelatorio({
    required this.secao,
    required this.linhas,
    this.totais = const {},
    this.observacao,
  });
}

// Serviço
class RelatorioService {
  final Db _db;
  final PrevisaoEstoqueService _previsao;

  RelatorioService({Db? db, PrevisaoEstoqueService? previsao})
      : _db = db ?? Db.instance,
        _previsao = previsao ?? PrevisaoEstoqueService();

  static const _topRanking = 10;

  /// Abaixo deste percentual do estoque vendido no período, o produto é
  /// considerado de baixo giro.
  static const _percentualBaixoGiro = 0.10;

  static const _unidadesFracionaveis = {'kg', 'g', 'L', 'mL'};
  Future<bool> salvar(ConfigRelatorio cfg) async {
    final bytes = await gerar(cfg);

    final caminho = await FilePicker.platform.saveFile(
      dialogTitle: 'Salvar relatório',
      fileName: _nomeArquivo(cfg),
      bytes: bytes,
    );

    return caminho != null;
  }

  /// Gera o arquivo em um diretório temporário e abre a aba de
  /// compartilhamento padrão do Android.
  Future<void> compartilhar(ConfigRelatorio cfg) async {
    final bytes = await gerar(cfg);
    final nome = _nomeArquivo(cfg);

    final tempDir = await getTemporaryDirectory();
    final arquivo = File('${tempDir.path}/$nome');
    await arquivo.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(arquivo.path)],
        subject: '${cfg.titulo}: myStock',
      ),
    );
  }

  Future<Uint8List> gerar(ConfigRelatorio cfg) async {
    final tabelas = await montar(cfg);
    if (cfg.formato == FormatoExportacao.csv) return _csv(tabelas, cfg);
    return _pdf(tabelas, cfg);
  }

  /// Calcula as tabelas das seções marcadas, sempre na ordem do catálogo.
  Future<List<TabelaRelatorio>> montar(ConfigRelatorio cfg) async {
    final tabelas = <TabelaRelatorio>[];
    List<_VendaDet>? vendasCache;
    Future<List<_VendaDet>> vendasDoPeriodo() async =>
        vendasCache ??= await _buscarVendas(cfg.periodo);

    for (final secao in SecaoRelatorio.values) {
      final colunas = cfg.selecao[secao];
      if (colunas == null || colunas.isEmpty) continue;

      switch (secao) {
        case SecaoRelatorio.posicaoEstoque:
          tabelas.add(await _posicaoEstoque());
        case SecaoRelatorio.validade:
          tabelas.add(await _validade(cfg.diasValidade));
        case SecaoRelatorio.perdas:
          tabelas.add(await _perdas(cfg.periodo));
        case SecaoRelatorio.vendas:
          tabelas.add(_vendas(await vendasDoPeriodo()));
        case SecaoRelatorio.maisVendidos:
          tabelas.add(_ranking(
              secao, await vendasDoPeriodo(), porLucro: false));
        case SecaoRelatorio.maisLucrativos:
          tabelas.add(_ranking(
              secao, await vendasDoPeriodo(), porLucro: true));
        case SecaoRelatorio.baixoGiro:
          tabelas.add(await _baixoGiro(await vendasDoPeriodo(), cfg.periodo));
        case SecaoRelatorio.reposicao:
          tabelas.add(await _reposicao(cfg.diasCobertura));
        case SecaoRelatorio.movimentacoes:
          tabelas.add(await _movimentacoes(cfg.periodo));
      }
    }

    return tabelas;
  }

  // Construção das tabelas
  // Posição de estoque
  Future<List<_EstoqueProduto>> _carregarEstoque() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        p.id, p.nome, p.codigo_barras, p.unidade, p.estoque_min,
        COALESCE(c.nome, '') AS categoria,
        COALESCE(SUM(l.quantidade), 0) AS qtd,
        COALESCE(SUM(l.quantidade * l.preco_custo), 0) AS valor_custo,
        COALESCE(SUM(l.quantidade * l.preco_venda), 0) AS valor_venda,
        (SELECT lx.preco_custo FROM lotes_produto lx
          WHERE lx.produto_id = p.id AND lx.ativo = 1
          ORDER BY lx.data_entrada DESC, lx.id DESC LIMIT 1) AS ultimo_custo
      FROM produtos p
      LEFT JOIN categorias c ON c.id = p.categoria_id
      LEFT JOIN lotes_produto l
        ON l.produto_id = p.id AND l.ativo = 1 AND l.status = 'ATIVO'
      WHERE p.ativo = 1
      GROUP BY p.id
      ORDER BY p.nome COLLATE NOCASE
    ''');

    return rows
        .map((r) => _EstoqueProduto(
      id: r['id'] as int,
      nome: r['nome'] as String,
      categoria: r['categoria'] as String,
      codigo: (r['codigo_barras'] as String?) ?? '',
      unidade: r['unidade'] as String,
      estoqueMin: r['estoque_min'] as int?,
      qtd: (r['qtd'] as num).toDouble(),
      valorCusto: (r['valor_custo'] as num).toDouble(),
      valorVenda: (r['valor_venda'] as num).toDouble(),
      ultimoCusto: (r['ultimo_custo'] as num?)?.toDouble(),
    ))
        .toList();
  }

  Future<TabelaRelatorio> _posicaoEstoque() async {
    final itens = await _carregarEstoque();

    var totalCusto = 0.0;
    var totalVenda = 0.0;
    final linhas = <Map<String, String>>[];

    for (final e in itens) {
      totalCusto += e.valorCusto;
      totalVenda += e.valorVenda;
      linhas.add({
        'produto': e.nome,
        'categoria': e.categoria,
        'codigo': e.codigo,
        'unidade': e.unidade,
        'quantidade': _qtd(e.qtd),
        'custo_medio': e.qtd > 0 ? _num(e.valorCusto / e.qtd) : '',
        'preco_medio': e.qtd > 0 ? _num(e.valorVenda / e.qtd) : '',
        'valor_custo': _num(e.valorCusto),
        'valor_venda': _num(e.valorVenda),
      });
    }

    return TabelaRelatorio(
      secao: SecaoRelatorio.posicaoEstoque,
      linhas: linhas,
      totais: {
        'valor_custo': _num(totalCusto),
        'valor_venda': _num(totalVenda),
      },
      observacao: 'Considera só os lotes ativos (não vencidos nem esgotados). '
          'Custo e preço médios ponderados pela quantidade de cada lote.',
    );
  }

  // Validade
  Future<TabelaRelatorio> _validade(int janelaDias) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT p.nome, p.unidade, l.id AS lote_id, l.numero_lote, l.quantidade,
             l.preco_custo, l.preco_venda, l.data_validade
      FROM lotes_produto l
      JOIN produtos p ON p.id = l.produto_id
      WHERE l.ativo = 1 AND p.ativo = 1 AND l.quantidade > 0
        AND l.status IN ('ATIVO', 'VENCIDO')
      ORDER BY l.data_validade ASC
    ''');

    final hoje = _soData(DateTime.now());
    final limite = DateTime(hoje.year, hoje.month, hoje.day + janelaDias);

    var vencidos = 0;
    var aVencer = 0;
    var riscoVencidos = 0.0;
    var riscoAVencer = 0.0;
    var totalCusto = 0.0;
    var totalVenda = 0.0;
    final linhas = <Map<String, String>>[];

    for (final r in rows) {
      final validade = _parseDb(r['data_validade']);
      if (validade == null) continue;

      final dv = _soData(validade);
      if (dv.isAfter(limite)) continue;

      final diasRest = (dv.difference(hoje).inHours / 24).round();
      final qtd = (r['quantidade'] as num).toDouble();
      final riscoCusto = qtd * (r['preco_custo'] as num).toDouble();
      final riscoVenda = qtd * (r['preco_venda'] as num).toDouble();

      final String situacao;
      if (diasRest < 0) {
        situacao = 'Vencido';
        vencidos++;
        riscoVencidos += riscoCusto;
      } else if (diasRest == 0) {
        situacao = 'Vence hoje';
        aVencer++;
        riscoAVencer += riscoCusto;
      } else {
        situacao = 'A vencer';
        aVencer++;
        riscoAVencer += riscoCusto;
      }

      totalCusto += riscoCusto;
      totalVenda += riscoVenda;

      linhas.add({
        'produto': r['nome'] as String,
        'lote': (r['numero_lote'] as String?) ?? '#${r['lote_id']}',
        'validade': _data(validade),
        'dias': '$diasRest',
        'situacao': situacao,
        'quantidade': _qtd(qtd),
        'unidade': r['unidade'] as String,
        'risco_custo': _num(riscoCusto),
        'risco_venda': _num(riscoVenda),
      });
    }

    return TabelaRelatorio(
      secao: SecaoRelatorio.validade,
      linhas: linhas,
      totais: {
        'risco_custo': _num(totalCusto),
        'risco_venda': _num(totalVenda),
      },
      observacao: 'Vencidos: $vencidos lote(s), R\$ ${_num(riscoVencidos)} em '
          'custo. A vencer em até $janelaDias dia(s): $aVencer lote(s), '
          'R\$ ${_num(riscoAVencer)} em custo.',
    );
  }

  // Perdas e movimentações
  Future<List<_Mov>> _buscarMovimentacoes(
      PeriodoRelatorio periodo, {
        required bool apenasPerdas,
      }) async {
    final db = await _db.database;
    final filtroPerda = apenasPerdas ? "AND m.tipo = 'PERDA'" : '';

    final rows = await db.rawQuery('''
      SELECT m.criado_em, m.tipo, m.motivo, m.quantidade, m.observacao,
             l.id AS lote_id, l.numero_lote, l.preco_custo,
             COALESCE(p.nome, 'Produto removido') AS produto,
             COALESCE(p.unidade, '') AS unidade
      FROM movimentacoes_estoque m
      JOIN lotes_produto l ON l.id = m.lote_id
      LEFT JOIN produtos p ON p.id = l.produto_id
      WHERE m.criado_em >= ?
        $filtroPerda
      ORDER BY m.id DESC
    ''', [_diaIso(periodo.desde.subtract(const Duration(days: 1)))]);

    final lista = <_Mov>[];
    for (final r in rows) {
      final data = _parseDb(r['criado_em']);
      if (data == null || !periodo.contem(data)) continue;

      lista.add(_Mov(
        data: data,
        tipo: r['tipo'] as String,
        motivo: r['motivo'] as String?,
        quantidade: (r['quantidade'] as num).toDouble(),
        observacao: (r['observacao'] as String?) ?? '',
        lote: (r['numero_lote'] as String?) ?? '#${r['lote_id']}',
        custo: (r['preco_custo'] as num).toDouble(),
        produto: r['produto'] as String,
        unidade: r['unidade'] as String,
      ));
    }

    lista.sort((a, b) => b.data.compareTo(a.data));
    return lista;
  }

  Future<TabelaRelatorio> _perdas(PeriodoRelatorio periodo) async {
    final movs = await _buscarMovimentacoes(periodo, apenasPerdas: true);

    var total = 0.0;
    final linhas = <Map<String, String>>[];
    for (final m in movs) {
      final valor = m.quantidade * m.custo;
      total += valor;
      linhas.add({
        'data': _dataHora(m.data),
        'produto': m.produto,
        'lote': m.lote,
        'motivo': MotivoMovimentacaoExt.fromString(m.motivo)?.label ?? '',
        'quantidade': _qtd(m.quantidade),
        'unidade': m.unidade,
        'valor': _num(valor),
        'observacao': m.observacao,
      });
    }

    return TabelaRelatorio(
      secao: SecaoRelatorio.perdas,
      linhas: linhas,
      totais: {'valor': _num(total)},
      observacao: 'Período: ${periodo.rotulo}. O valor perdido usa o custo '
          'atual do lote (o custo no momento da perda não é guardado).',
    );
  }

  Future<TabelaRelatorio> _movimentacoes(PeriodoRelatorio periodo) async {
    final movs = await _buscarMovimentacoes(periodo, apenasPerdas: false);

    final linhas = movs
        .map((m) => <String, String>{
      'data': _dataHora(m.data),
      'produto': m.produto,
      'lote': m.lote,
      'tipo': TipoMovimentacaoExt.fromString(m.tipo).label,
      'motivo': MotivoMovimentacaoExt.fromString(m.motivo)?.label ?? '',
      'quantidade': _qtd(m.quantidade),
      'unidade': m.unidade,
      'observacao': m.observacao,
    })
        .toList();

    return TabelaRelatorio(
      secao: SecaoRelatorio.movimentacoes,
      linhas: linhas,
      observacao: 'Período: ${periodo.rotulo}. ${linhas.length} '
          'movimentação(ões).',
    );
  }

  // Vendas
  Future<List<_VendaDet>> _buscarVendas(PeriodoRelatorio periodo) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT v.id AS venda_id, v.valor_total, v.criado_em AS venda_em,
             vi.quantidade, vi.subtotal, vi.produto_id,
             COALESCE(p.nome, 'Produto removido') AS produto,
             COALESCE(p.unidade, '') AS unidade,
             COALESCE(lp.preco_custo, 0) AS custo
      FROM vendas v
      LEFT JOIN venda_itens vi ON vi.venda_id = v.id
      LEFT JOIN produtos p ON p.id = vi.produto_id
      LEFT JOIN lotes_produto lp ON lp.id = vi.lote_id
      WHERE v.criado_em >= ?
      ORDER BY v.id ASC, vi.id ASC
    ''', [_diaIso(periodo.desde.subtract(const Duration(days: 1)))]);

    final porVenda = <int, _VendaDet>{};
    for (final r in rows) {
      final id = r['venda_id'] as int;
      final venda = porVenda.putIfAbsent(
        id,
            () => _VendaDet(
          id: id,
          data: _parseDb(r['venda_em']),
          total: (r['valor_total'] as num).toDouble(),
        ),
      );

      if (r['quantidade'] == null) continue;

      venda.itens.add(_ItemVenda(
        produtoId: r['produto_id'] as int?,
        produto: r['produto'] as String,
        unidade: r['unidade'] as String,
        quantidade: (r['quantidade'] as num).toDouble(),
        subtotal: (r['subtotal'] as num).toDouble(),
        custo: (r['custo'] as num).toDouble(),
      ));
    }

    final lista = porVenda.values
        .where((v) => v.data != null && periodo.contem(v.data!))
        .toList()
      ..sort((a, b) => b.data!.compareTo(a.data!));
    return lista;
  }

  TabelaRelatorio _vendas(List<_VendaDet> vendas) {
    var totalReceita = 0.0;
    var totalLucro = 0.0;
    final linhas = <Map<String, String>>[];

    for (final v in vendas) {
      totalReceita += v.total;
      totalLucro += v.lucro;

      linhas.add({
        'codigo': '#${v.id}',
        'data': _dataHora(v.data!),
        'produtos': v.itens
            .map((i) => '${_qtd(i.quantidade)}'
            '${i.unidade.isEmpty ? '' : ' ${i.unidade}'} ${i.produto}')
            .join('; '),
        'receita': _num(v.total),
        'lucro': _num(v.lucro),
        'margem': v.total > 0 ? _pct(v.lucro / v.total * 100) : '',
      });
    }

    return TabelaRelatorio(
      secao: SecaoRelatorio.vendas,
      linhas: linhas,
      totais: {
        'codigo': 'TOTAL (${vendas.length} venda(s))',
        'receita': _num(totalReceita),
        'lucro': _num(totalLucro),
        'margem': totalReceita > 0 ? _pct(totalLucro / totalReceita * 100) : '',
      },
      observacao: 'Lucro calculado com o custo atual de cada lote (o custo '
          'no momento da venda não é guardado).',
    );
  }

  Map<int, _AggProduto> _agregar(List<_VendaDet> vendas) {
    final mapa = <int, _AggProduto>{};
    for (final v in vendas) {
      for (final i in v.itens) {
        final agg = mapa.putIfAbsent(
            i.produtoId ?? -1, () => _AggProduto(i.produto, i.unidade));
        agg.qtd += i.quantidade;
        agg.receita += i.subtotal;
        agg.lucro += i.lucro;
      }
    }
    return mapa;
  }

  TabelaRelatorio _ranking(
      SecaoRelatorio secao,
      List<_VendaDet> vendas, {
        required bool porLucro,
      }) {
    final lista = _agregar(vendas).values.toList()
      ..sort((a, b) =>
      porLucro ? b.lucro.compareTo(a.lucro) : b.qtd.compareTo(a.qtd));
    final top = lista.take(_topRanking).toList();

    var totalReceita = 0.0;
    var totalLucro = 0.0;
    final linhas = <Map<String, String>>[];

    for (var i = 0; i < top.length; i++) {
      final a = top[i];
      totalReceita += a.receita;
      totalLucro += a.lucro;
      linhas.add({
        'pos': '${i + 1}',
        'produto': a.nome,
        'unidade': a.unidade,
        'quantidade': _qtd(a.qtd),
        'receita': _num(a.receita),
        'lucro': _num(a.lucro),
        'margem': a.receita > 0 ? _pct(a.lucro / a.receita * 100) : '',
      });
    }

    return TabelaRelatorio(
      secao: secao,
      linhas: linhas,
      totais: {
        'receita': _num(totalReceita),
        'lucro': _num(totalLucro),
      },
      observacao: 'Top $_topRanking do período. Lucro calculado com o custo '
          'atual do lote. A ordenação por quantidade soma unidades '
          'diferentes (un, kg...) sem converter.',
    );
  }

  Future<TabelaRelatorio> _baixoGiro(
      List<_VendaDet> vendas,
      PeriodoRelatorio periodo,
      ) async {
    final estoque = await _carregarEstoque();
    final agg = _agregar(vendas);

    final candidatos = <_EstoqueProduto, double>{};
    for (final e in estoque) {
      if (e.qtd <= 0) continue;
      final vendido = agg[e.id]?.qtd ?? 0;
      if (vendido >= e.qtd * _percentualBaixoGiro) continue;
      candidatos[e] = vendido;
    }

    final ordenados = candidatos.keys.toList()
      ..sort((a, b) => b.valorCusto.compareTo(a.valorCusto));

    var totalParado = 0.0;
    final linhas = <Map<String, String>>[];
    for (final e in ordenados) {
      final vendido = candidatos[e]!;
      totalParado += e.valorCusto;
      linhas.add({
        'produto': e.nome,
        'categoria': e.categoria,
        'unidade': e.unidade,
        'estoque': _qtd(e.qtd),
        'vendido': _qtd(vendido),
        'giro': _pct(vendido / e.qtd * 100),
        'valor_parado': _num(e.valorCusto),
      });
    }

    return TabelaRelatorio(
      secao: SecaoRelatorio.baixoGiro,
      linhas: linhas,
      totais: {'valor_parado': _num(totalParado)},
      observacao: 'Produtos com estoque que venderam menos de '
          '${(_percentualBaixoGiro * 100).round()}% dele em '
          '${periodo.rotulo}. Períodos curtos tendem a listar mais produtos.',
    );
  }

  // Reposição sugerida
  Future<TabelaRelatorio> _reposicao(int diasCobertura) async {
    final estoque = await _carregarEstoque();

    final sugestoes = <_Reposicao>[];
    for (final e in estoque) {
      // Média semanal pela Média Móvel Simples (MMS) das últimas 4 semanas,
      // ampliada para 12 quando houve poucas vendas recentes, a mesma regra
      // usada na tela de Análise.
      final prev = await _previsao.calcularPrevisao(e.id);
      final usaVendas = !prev.semPrevisaoConfiavel && prev.mediaSemanal != null;
      final mediaDia = usaVendas ? prev.mediaSemanal! / 7 : 0.0;
      final porVendas = mediaDia * diasCobertura;
      final minimo = (e.estoqueMin ?? 0).toDouble();
      final necessario = porVendas > minimo ? porVendas : minimo;

      if (e.qtd >= necessario) continue;

      final fracionavel = _unidadesFracionaveis.contains(e.unidade);
      var sugerido = necessario - e.qtd;
      var necessarioExib = necessario;
      if (!fracionavel) {
        sugerido = sugerido.ceilToDouble();
        necessarioExib = necessario.ceilToDouble();
      }

      sugestoes.add(_Reposicao(
        produto: e,
        mediaSemana: usaVendas ? prev.mediaSemanal : null,
        base: prev.baixaMovimentacao
            ? 'Baixa movimentação (só estoque mínimo)'
            : prev.regra.descricao,
        necessario: necessarioExib,
        sugerido: sugerido,
        urgencia: necessario > 0 ? e.qtd / necessario : 0,
      ));
    }

    sugestoes.sort((a, b) => a.urgencia.compareTo(b.urgencia));

    var totalCusto = 0.0;
    final linhas = <Map<String, String>>[];
    for (final s in sugestoes) {
      final e = s.produto;
      final custo = e.ultimoCusto == null ? null : s.sugerido * e.ultimoCusto!;
      if (custo != null) totalCusto += custo;

      final mediaDia = (s.mediaSemana ?? 0) / 7;

      linhas.add({
        'produto': e.nome,
        'unidade': e.unidade,
        'estoque': _qtd(e.qtd),
        'media_semana': s.mediaSemana == null ? '' : _qtd(s.mediaSemana!),
        'base': s.base,
        'cobertura': mediaDia > 0 ? _num(e.qtd / mediaDia, 1) : '',
        'minimo': e.estoqueMin == null ? '' : '${e.estoqueMin}',
        'necessario': _qtd(s.necessario),
        'sugerido': _qtd(s.sugerido),
        'custo': custo == null ? '' : _num(custo),
      });
    }

    return TabelaRelatorio(
      secao: SecaoRelatorio.reposicao,
      linhas: linhas,
      totais: {'custo': _num(totalCusto)},
      observacao: 'Média semanal pela Média Móvel Simples das últimas 4 '
          'semanas; com vendas em menos de 3 delas, usa as últimas 12 '
          '(produto com menos de 4 semanas de cadastro usa o histórico desde '
          'o cadastro). Necessário = média semanal / 7 x $diasCobertura dias '
          'de cobertura, ou o estoque mínimo, o que for maior. Produtos com '
          'baixa movimentação (menos de 5 unidades na janela) ou sem '
          'histórico só entram se estiverem abaixo do estoque mínimo. Custo '
          'estimado usa o custo do lote mais recente.',
    );
  }

  // Geração dos arquivos
  List<ColunaRelatorio> _colunasMarcadas(
      SecaoRelatorio secao, ConfigRelatorio cfg) {
    final ids = cfg.selecao[secao] ?? const <String>{};
    return secao.colunas.where((c) => ids.contains(c.id)).toList();
  }

  List<String> _linhaTotal(
      List<ColunaRelatorio> cols, Map<String, String> totais) {
    final cells = cols.map((c) => totais[c.id] ?? '').toList();
    if (cells.first.isEmpty) cells[0] = 'TOTAL';
    return cells;
  }

  bool _usaPeriodo(ConfigRelatorio cfg) =>
      cfg.selecao.keys.any((s) => s.usaPeriodo);

  Uint8List _csv(List<TabelaRelatorio> tabelas, ConfigRelatorio cfg) {
    final linhas = <List<String>>[
      [cfg.titulo],
      ['Gerado em ${_dataHora(DateTime.now())}'],
      if (_usaPeriodo(cfg)) ['Período: ${cfg.periodo.rotulo}'],
    ];

    for (final t in tabelas) {
      final cols = _colunasMarcadas(t.secao, cfg);
      if (cols.isEmpty) continue;

      linhas.add(['']);
      linhas.add([t.secao.titulo]);
      if (t.observacao != null) linhas.add([t.observacao!]);
      linhas.add(cols.map((c) => c.titulo).toList());

      if (t.linhas.isEmpty) {
        linhas.add(['Nenhum registro encontrado.']);
        continue;
      }

      for (final l in t.linhas) {
        linhas.add(cols.map((c) => l[c.id] ?? '').toList());
      }
      if (t.totais.isNotEmpty) linhas.add(_linhaTotal(cols, t.totais));
    }

    // ';' como separador porque é o que o Excel em pt-BR espera por padrão.
    final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(linhas);
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
  }

  Future<Uint8List> _pdf(
      List<TabelaRelatorio> tabelas, ConfigRelatorio cfg) async {
    final widgets = <pw.Widget>[];

    for (final t in tabelas) {
      final cols = _colunasMarcadas(t.secao, cfg);
      if (cols.isEmpty) continue;

      widgets.add(pw.SizedBox(height: 14));
      widgets.add(pw.Text(
        t.secao.titulo,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ));
      if (t.observacao != null) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2, bottom: 6),
          child: pw.Text(
            t.observacao!,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ));
      }

      if (t.linhas.isEmpty) {
        widgets.add(pw.Text(
          'Nenhum registro encontrado.',
          style: const pw.TextStyle(fontSize: 9),
        ));
        continue;
      }

      final dados = t.linhas
          .map((l) => cols.map((c) => l[c.id] ?? '').toList())
          .toList();
      if (t.totais.isNotEmpty) dados.add(_linhaTotal(cols, t.totais));

      final alinhamentos = <int, pw.Alignment>{
        for (var i = 0; i < cols.length; i++)
          if (cols[i].numerica) i: pw.Alignment.centerRight,
      };

      widgets.add(pw.TableHelper.fromTextArray(
        headers: cols.map((c) => c.titulo).toList(),
        data: dados,
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 7),
        cellAlignment: pw.Alignment.centerLeft,
        cellAlignments: alinhamentos,
        headerAlignments: alinhamentos,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      ));
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        maxPages: 1000,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${cfg.titulo} - myStock',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Gerado em ${_dataHora(DateTime.now())}'
                  '${_usaPeriodo(cfg) ? '  |  Período: ${cfg.periodo.rotulo}' : ''}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (context) => widgets,
      ),
    );

    return doc.save();
  }

  String _nomeArquivo(ConfigRelatorio cfg) {
    final agora = DateTime.now();
    final carimbo = '${agora.year}${_dois(agora.month)}${_dois(agora.day)}_'
        '${_dois(agora.hour)}${_dois(agora.minute)}';
    final ext = cfg.formato == FormatoExportacao.csv ? 'csv' : 'pdf';
    return 'mystock_${cfg.arquivo}_$carimbo.$ext';
  }
}

// Tipos internos
class _EstoqueProduto {
  final int id;
  final String nome;
  final String categoria;
  final String codigo;
  final String unidade;
  final int? estoqueMin;
  final double qtd;
  final double valorCusto;
  final double valorVenda;
  final double? ultimoCusto;

  const _EstoqueProduto({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.codigo,
    required this.unidade,
    required this.estoqueMin,
    required this.qtd,
    required this.valorCusto,
    required this.valorVenda,
    required this.ultimoCusto,
  });
}

class _ItemVenda {
  final int? produtoId;
  final String produto;
  final String unidade;
  final double quantidade;
  final double subtotal;
  final double custo;

  const _ItemVenda({
    required this.produtoId,
    required this.produto,
    required this.unidade,
    required this.quantidade,
    required this.subtotal,
    required this.custo,
  });

  double get lucro => subtotal - (quantidade * custo);
}

class _VendaDet {
  final int id;
  final DateTime? data;
  final double total;
  final List<_ItemVenda> itens = [];

  _VendaDet({required this.id, required this.data, required this.total});

  double get lucro => itens.fold(0.0, (acc, i) => acc + i.lucro);
}

class _AggProduto {
  final String nome;
  final String unidade;
  double qtd = 0;
  double receita = 0;
  double lucro = 0;

  _AggProduto(this.nome, this.unidade);
}

class _Mov {
  final DateTime data;
  final String tipo;
  final String? motivo;
  final double quantidade;
  final String observacao;
  final String lote;
  final double custo;
  final String produto;
  final String unidade;

  const _Mov({
    required this.data,
    required this.tipo,
    required this.motivo,
    required this.quantidade,
    required this.observacao,
    required this.lote,
    required this.custo,
    required this.produto,
    required this.unidade,
  });
}

class _Reposicao {
  final _EstoqueProduto produto;

  /// Média semanal (MMS); null quando não há previsão confiável.
  final double? mediaSemana;

  /// Texto da janela usada ("Baseado nas últimas 4 semanas"...).
  final String base;
  final double necessario;
  final double sugerido;
  final double urgencia;

  const _Reposicao({
    required this.produto,
    required this.mediaSemana,
    required this.base,
    required this.necessario,
    required this.sugerido,
    required this.urgencia,
  });
}

// Formatação e datas
String _dois(int n) => n.toString().padLeft(2, '0');

/// Vírgula decimal, sem símbolo de moeda: o Excel pt-BR entende como número
String _num(double v, [int casas = 2]) =>
    v.toStringAsFixed(casas).replaceAll('.', ',');

String _qtd(double v) {
  final r = (v * 1000).round() / 1000;
  return r == r.roundToDouble()
      ? r.toStringAsFixed(0)
      : r.toString().replaceAll('.', ',');
}

String _pct(double v) => '${_num(v, 1)}%';

String _data(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}/${d.year}';

String _dataHora(DateTime d) =>
    '${_data(d)} ${_dois(d.hour)}:${_dois(d.minute)}';

DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

String _diaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_dois(d.month)}-${_dois(d.day)}';

/// Lê uma data guardada no banco. O SQLite grava `datetime('now')` (vendas,
/// movimentações feitas direto por SQL) como 'YYYY-MM-DD HH:MM:SS' em UTC;
/// já o que o app grava via `toIso8601String()` vem com 'T' e em hora
/// local. Normaliza os dois para hora local.
DateTime? _parseDb(Object? v) {
  if (v is! String || v.isEmpty) return null;
  if (v.length == 19 && v[10] == ' ') {
    return DateTime.tryParse('${v.replaceFirst(' ', 'T')}Z')?.toLocal();
  }
  return DateTime.tryParse(v);
}