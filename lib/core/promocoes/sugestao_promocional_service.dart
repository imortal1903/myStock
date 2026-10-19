import '../extensions/quantidade_extensions.dart';
import '../../features/crud/repositories/produto_repository.dart';
import '../../features/crud/repositories/lote_repository.dart';
import '../../features/crud/repositories/movimentacao_repository.dart';

enum MotivoSugestao { baixaRotatividade, vencimentoProximo, estoqueBaixo }

class SugestaoPromocional {
  final int produtoId;
  final String produtoNome;
  final MotivoSugestao motivo;
  final String texto;
  final String? detalhe;

  const SugestaoPromocional({
    required this.produtoId,
    required this.produtoNome,
    required this.motivo,
    required this.texto,
    this.detalhe,
  });
}

/// Gera sugestões de ação promocional para o card do dashboard da Home
class SugestaoPromocionalService {
  final ProdutoRepository _produtoRepo;
  final LoteRepository _loteRepo;
  final MovimentacaoRepository _movRepo;

  SugestaoPromocionalService({
    ProdutoRepository? produtoRepo,
    LoteRepository? loteRepo,
    MovimentacaoRepository? movRepo,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo = loteRepo ?? LoteRepository(),
        _movRepo = movRepo ?? MovimentacaoRepository();

  static const _diasVencimentoProximo = 7;
  static const _diasJanelaVendas = 30;
  static const _percentualMinimoVendido = 0.10;

  static const _textoBaixaRotatividade = 'Baixa saída nos últimos '
      '$_diasJanelaVendas dias - considere uma promoção para girar o estoque.';
  static const _textoEstoqueBaixo =
      'Estoque abaixo do mínimo - considere repor.';
  static const _textoVencimentoProximo =
      'Vencimento próximo - considere uma promoção para acelerar a saída.';

  Future<List<SugestaoPromocional>> gerarSugestoes() async {
    final vencendo = await _sugestoesVencimentoProximo();
    final estoqueBaixo = await _sugestoesEstoqueBaixo();
    final baixaRotatividade = await _sugestoesBaixaRotatividade();

    // Do mais urgente pro menos: vencimento, falta de estoque, baixa saída.
    return [...vencendo, ...estoqueBaixo, ...baixaRotatividade];
  }

  /// Produtos com estoque ativo abaixo do estoque mínimo cadastrado
  /// (`Produto.estoqueMin`). Produto sem estoque mínimo definido não é
  /// avaliado. Os mais críticos (menor proporção do mínimo) vêm primeiro.
  Future<List<SugestaoPromocional>> _sugestoesEstoqueBaixo() async {
    final resumo = await _loteRepo.getResumoEstoquePorProduto();
    final produtos = await _produtoRepo.search('');

    final candidatos = <(double, SugestaoPromocional)>[];
    for (final p in produtos) {
      final minimo = p.estoqueMin;
      if (minimo == null || minimo <= 0) continue;

      // Sem nenhum lote ativo, o estoque é 0 (e o produto precisa de reposição).
      final atual = resumo[p.id]?.quantidadeAtiva ?? 0.0;
      if (atual >= minimo) continue;

      candidatos.add((
      atual / minimo,
      SugestaoPromocional(
        produtoId: p.id!,
        produtoNome: p.nome,
        motivo: MotivoSugestao.estoqueBaixo,
        texto: _textoEstoqueBaixo,
        detalhe: '${atual.formatada} de $minimo ${p.unidade}',
      ),
      ));
    }

    candidatos.sort((a, b) => a.$1.compareTo(b.$1));
    return candidatos.map((c) => c.$2).toList();
  }

  Future<List<SugestaoPromocional>> _sugestoesVencimentoProximo() async {
    final lotes =
    await _loteRepo.getLotesProximosVencimento(_diasVencimentoProximo);

    final produtoIds = <int>{};
    for (final l in lotes) {
      if (l.estaVencido) continue;
      produtoIds.add(l.produtoId);
    }

    final sugestoes = <SugestaoPromocional>[];
    for (final produtoId in produtoIds) {
      final produto = await _produtoRepo.getById(produtoId);
      if (produto == null || !produto.ativo) continue;

      sugestoes.add(SugestaoPromocional(
        produtoId: produtoId,
        produtoNome: produto.nome,
        motivo: MotivoSugestao.vencimentoProximo,
        texto: _textoVencimentoProximo,
      ));
    }

    return sugestoes;
  }

  Future<List<SugestaoPromocional>> _sugestoesBaixaRotatividade() async {
    final resumo = await _loteRepo.getResumoEstoquePorProduto();
    final desde =
    DateTime.now().subtract(const Duration(days: _diasJanelaVendas));
    final vendidoPorProduto = await _movRepo.getVendidoPorProdutoDesde(desde);

    final sugestoes = <SugestaoPromocional>[];

    for (final entry in resumo.entries) {
      final produtoId = entry.key;
      final estoqueAtivo = entry.value.quantidadeAtiva;
      if (estoqueAtivo <= 0) continue;

      final vendido = vendidoPorProduto[produtoId] ?? 0;
      if (vendido >= estoqueAtivo * _percentualMinimoVendido) continue;

      final produto = await _produtoRepo.getById(produtoId);
      if (produto == null || !produto.ativo) continue;

      sugestoes.add(SugestaoPromocional(
        produtoId: produtoId,
        produtoNome: produto.nome,
        motivo: MotivoSugestao.baixaRotatividade,
        texto: _textoBaixaRotatividade,
      ));
    }

    return sugestoes;
  }
}