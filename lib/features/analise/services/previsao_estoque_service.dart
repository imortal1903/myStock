import '../../crud/models/lote.dart';
import '../../crud/repositories/produto_repository.dart';
import '../../crud/repositories/lote_repository.dart';
import '../../venda/repositories/venda_repository.dart';
import '../../../core/extensions/quantidade_extensions.dart';

enum RegraJanela { semanalPadrao, estendida, produtoNovo, semDadosSuficientes }

extension RegraJanelaExt on RegraJanela {
  String get descricao {
    switch (this) {
      case RegraJanela.semanalPadrao:
        return 'Baseado nas últimas 4 semanas';
      case RegraJanela.estendida:
        return 'Baseado nas últimas 12 semanas (vendas recentes esparsas)';
      case RegraJanela.produtoNovo:
        return 'Baseado no histórico desde o cadastro do produto';
      case RegraJanela.semDadosSuficientes:
        return 'Sem histórico de vendas suficiente';
    }
  }
}

class PrevisaoEstoque {
  final int produtoId;
  final double estoqueAtual;
  final double? mediaSemanal;
  final int janelaSemanas;
  final RegraJanela regra;
  final bool baixaMovimentacao;
  final double? semanasRestantes;

  const PrevisaoEstoque({
    required this.produtoId,
    required this.estoqueAtual,
    required this.mediaSemanal,
    required this.janelaSemanas,
    required this.regra,
    required this.baixaMovimentacao,
    required this.semanasRestantes,
  });

  /// Se `true`, não há dado confiável o bastante para mostrar uma previsão
  /// numérica de duração - a UI deve mostrar uma mensagem qualitativa
  /// ("Baixa movimentação") em vez de "X semanas restantes".
  bool get semPrevisaoConfiavel =>
      regra == RegraJanela.semDadosSuficientes || baixaMovimentacao;
}

/// Um lote cuja quantidade projetada de venda, até a data de vencimento,
/// não é suficiente para escoar todo o estoque restante dele.
class LoteEmRisco {
  final Lote lote;
  final double vendidoEstimado;
  final double quantidadeEmRisco;

  const LoteEmRisco({
    required this.lote,
    required this.vendidoEstimado,
    required this.quantidadeEmRisco,
  });
}

class PrevisaoEstoqueService {
  final ProdutoRepository _produtoRepo;
  final LoteRepository _loteRepo;
  final VendaRepository _vendaRepo;

  /// Abaixo deste total vendido na janela usada, a movimentação é
  /// considerada baixa demais para projetar com confiança (evita previsões
  /// do tipo "692 semanas" a partir de 1 venda isolada).
  static const int _limiarBaixaMovimentacao = 5;
  static const int _janelaPadrao = 4;
  static const int _janelaEstendida = 12;

  PrevisaoEstoqueService({
    ProdutoRepository? produtoRepo,
    LoteRepository? loteRepo,
    VendaRepository? vendaRepo,
  })  : _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo = loteRepo ?? LoteRepository(),
        _vendaRepo = vendaRepo ?? VendaRepository();

  // Média semanal (regra de janela adaptativa)
  //
  // | Situação                          | Janela usada       |
  // |------------------------------------|--------------------|
  // | Vendeu em >= 3 das últimas 4 sem.  | 4 semanas          |
  // | Vendeu em 1-2 das últimas 4 sem.   | 12 semanas         |
  // | Produto com < 4 semanas de vida    | desde a criação    |
  // | Nenhuma venda na janela disponível | sem previsão       |

  Future<PrevisaoEstoque> calcularPrevisao(int produtoId) async {
    final produto = await _produtoRepo.getById(produtoId);
    final lotes = await _loteRepo.getByProduto(produtoId);
    final estoqueAtual = lotes
        .where((l) => l.status == LoteStatus.ativo)
        .fold<double>(0.0, (acc, l) => acc + l.quantidade);

    if (produto == null) {
      return _semDados(produtoId, estoqueAtual);
    }

    final semanasDesdeCriacao =
        DateTime.now().difference(produto.criadoEm).inDays / 7;

    if (semanasDesdeCriacao < _janelaPadrao) {
      final janela = semanasDesdeCriacao.ceil().clamp(1, _janelaPadrao);
      final vendas =
          await _vendaRepo.getVendasPorSemana(produtoId, semanas: janela);
      final total = vendas.fold<double>(0.0, (a, b) => a + b);

      if (total == 0) return _semDados(produtoId, estoqueAtual);

      final media = total / janela;
      return PrevisaoEstoque(
        produtoId: produtoId,
        estoqueAtual: estoqueAtual,
        mediaSemanal: media,
        janelaSemanas: janela,
        regra: RegraJanela.produtoNovo,
        baixaMovimentacao: total < _limiarBaixaMovimentacao,
        semanasRestantes: media > 0 ? estoqueAtual / media : null,
      );
    }

    final vendas4 =
        await _vendaRepo.getVendasPorSemana(produtoId, semanas: _janelaPadrao);
    final semanasComVenda4 = vendas4.where((v) => v > 0).length;
    final total4 = vendas4.fold<double>(0.0, (a, b) => a + b);

    if (semanasComVenda4 >= 3) {
      final media = total4 / _janelaPadrao;
      return PrevisaoEstoque(
        produtoId: produtoId,
        estoqueAtual: estoqueAtual,
        mediaSemanal: media,
        janelaSemanas: _janelaPadrao,
        regra: RegraJanela.semanalPadrao,
        baixaMovimentacao: total4 < _limiarBaixaMovimentacao,
        semanasRestantes: media > 0 ? estoqueAtual / media : null,
      );
    }

    final vendasEstendida = await _vendaRepo.getVendasPorSemana(produtoId,
        semanas: _janelaEstendida);
    final totalEstendido = vendasEstendida.fold<double>(0.0, (a, b) => a + b);

    if (totalEstendido == 0) return _semDados(produtoId, estoqueAtual);

    final media = totalEstendido / _janelaEstendida;
    return PrevisaoEstoque(
      produtoId: produtoId,
      estoqueAtual: estoqueAtual,
      mediaSemanal: media,
      janelaSemanas: _janelaEstendida,
      regra: RegraJanela.estendida,
      baixaMovimentacao: totalEstendido < _limiarBaixaMovimentacao,
      semanasRestantes: media > 0 ? estoqueAtual / media : null,
    );
  }

  PrevisaoEstoque _semDados(int produtoId, double estoqueAtual) =>
      PrevisaoEstoque(
        produtoId: produtoId,
        estoqueAtual: estoqueAtual,
        mediaSemanal: null,
        janelaSemanas: 0,
        regra: RegraJanela.semDadosSuficientes,
        baixaMovimentacao: false,
        semanasRestantes: null,
      );

  Future<List<LoteEmRisco>> simularRiscoVencimento(int produtoId) async {
    final previsao = await calcularPrevisao(produtoId);
    final mediaSemanal = previsao.mediaSemanal;
    if (mediaSemanal == null ||
        mediaSemanal <= 0 ||
        previsao.baixaMovimentacao) {
      return [];
    }

    final lotes = (await _loteRepo.getByProduto(produtoId))
        .where((l) => l.status == LoteStatus.ativo)
        .toList()
      ..sort((a, b) => a.dataValidade.compareTo(b.dataValidade));

    var demandaAcumulada = 0.0;
    final resultado = <LoteEmRisco>[];

    for (final lote in lotes) {
      final semanasAteVencer = lote.diasParaVencer / 7.0;
      final demandaTotalAteVencer = mediaSemanal * semanasAteVencer;
      final demandaDisponivel = (demandaTotalAteVencer - demandaAcumulada)
          .clamp(0.0, double.infinity);

      final vendidoEstimado = demandaDisponivel < lote.quantidade
          ? demandaDisponivel
          : lote.quantidade;

      final emRisco = lote.quantidade - vendidoEstimado;
      demandaAcumulada += vendidoEstimado;

      if (emRisco > 0.5) {
        resultado.add(LoteEmRisco(
          lote: lote,
          vendidoEstimado: vendidoEstimado.arredondada,
          quantidadeEmRisco: emRisco.arredondada,
        ));
      }
    }

    return resultado;
  }
}
