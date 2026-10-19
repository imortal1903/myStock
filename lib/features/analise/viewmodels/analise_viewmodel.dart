import 'dart:async';

import '../../crud/models/lote_com_produto.dart';
import '../../crud/models/movimentacao_estoque.dart';
import '../../crud/repositories/lote_repository.dart';
import '../../crud/repositories/movimentacao_repository.dart';
import '../../venda/repositories/venda_repository.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

/// Período usado para todos os cards e gráficos da tela de Análise.
enum PeriodoAnalise { dias7, dias30, dias90, dias365 }

extension PeriodoAnaliseExt on PeriodoAnalise {
  int get dias {
    switch (this) {
      case PeriodoAnalise.dias7:   return 7;
      case PeriodoAnalise.dias30:  return 30;
      case PeriodoAnalise.dias90:  return 90;
      case PeriodoAnalise.dias365: return 365;
    }
  }

  String get label {
    switch (this) {
      case PeriodoAnalise.dias7:   return '7 dias';
      case PeriodoAnalise.dias30:  return '30 dias';
      case PeriodoAnalise.dias90:  return '3 meses';
      case PeriodoAnalise.dias365: return '1 ano';
    }
  }
}

class ResumoSaidas {
  final double quantidadeVendida;
  final double faturamento;

  /// null quando não há período anterior com dados suficientes para
  /// comparar (evita mostrar "+infinito%" ou dividir por zero).
  final double? variacaoQuantidadePct;
  final double? variacaoFaturamentoPct;

  final double quantidadeVencida;

  /// Valor de custo total perdido no período, somando TODOS os motivos de
  /// perda
  final double valorPerdido;

  const ResumoSaidas({
    required this.quantidadeVendida,
    required this.faturamento,
    required this.variacaoQuantidadePct,
    required this.variacaoFaturamentoPct,
    required this.quantidadeVencida,
    required this.valorPerdido,
  });
}

class AnaliseViewModel extends BaseViewModel {
  final VendaRepository _vendaRepo;
  final MovimentacaoRepository _movRepo;
  final LoteRepository _loteRepo;

  /// Quantos dias de antecedência contam como "próximo do vencimento" na
  /// seção Atenção.
  static const int _diasAtencaoVencimento = 15;

  /// Recarrega os dados periodicamente enquanto a tela está aberta
  static const Duration _intervaloAutoRefresh = Duration(minutes: 1);
  Timer? _autoRefreshTimer;

  AnaliseViewModel({
    VendaRepository? vendaRepo,
    MovimentacaoRepository? movRepo,
    LoteRepository? loteRepo,
  })  : _vendaRepo = vendaRepo ?? VendaRepository(),
        _movRepo = movRepo ?? MovimentacaoRepository(),
        _loteRepo = loteRepo ?? LoteRepository() {
    _atualizarERecarregar();
    _autoRefreshTimer =
        Timer.periodic(_intervaloAutoRefresh, (_) => _atualizarERecarregar());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Promove lotes vencidos (e registra a perda correspondente)
  Future<void> _atualizarERecarregar() async {
    await _loteRepo.atualizarStatusVencidos();
    await carregar();
  }

  PeriodoAnalise _periodo = PeriodoAnalise.dias30;
  PeriodoAnalise get periodo => _periodo;

  ResumoSaidas? _resumo;
  ResumoSaidas? get resumo => _resumo;

  Map<String, double> _resumoPorMotivo = {};
  Map<String, double> get resumoPorMotivo => Map.unmodifiable(_resumoPorMotivo);

  List<LoteComProduto> _lotesEmAtencao = [];
  List<LoteComProduto> get lotesEmAtencao => List.unmodifiable(_lotesEmAtencao);

  Future<void> selecionarPeriodo(PeriodoAnalise p) async {
    if (_periodo == p) return;
    _periodo = p;
    await carregar();
  }

  Future<void> carregar() async {
    await run<void>(
          () async {
        final agora = DateTime.now();
        final inicioAtual = agora.subtract(Duration(days: _periodo.dias));
        final inicioAnterior = agora.subtract(Duration(days: _periodo.dias * 2));

        final atual = await _vendaRepo.getResumoPeriodo(inicioAtual, agora);
        final anterior =
        await _vendaRepo.getResumoPeriodo(inicioAnterior, inicioAtual);

        final vencidas = await _movRepo.getQuantidadePorMotivo(
          inicioAtual,
          agora,
          MotivoMovimentacao.vencimento,
        );

        final valorPerdido = await _movRepo.getValorPerdido(
          inicioAtual,
          agora,
          [
            MotivoMovimentacao.vencimento,
            MotivoMovimentacao.avaria,
            MotivoMovimentacao.roubo,
            MotivoMovimentacao.outro,
          ],
        );

        _resumo = ResumoSaidas(
          quantidadeVendida: atual['qtd']!.toDouble(),
          faturamento: atual['faturamento']!.toDouble(),
          variacaoQuantidadePct: _variacaoPct(
            anterior['qtd']!.toDouble(),
            atual['qtd']!.toDouble(),
          ),
          variacaoFaturamentoPct: _variacaoPct(
            anterior['faturamento']!.toDouble(),
            atual['faturamento']!.toDouble(),
          ),
          quantidadeVencida: vencidas,
          valorPerdido: valorPerdido,
        );

        _resumoPorMotivo = await _movRepo.getResumoPorMotivo(inicioAtual);
        _lotesEmAtencao = await _loteRepo
            .getLotesProximosVencimentoComProduto(_diasAtencaoVencimento);
      },
      onError: (e) => 'Erro ao carregar análise: $e',
    );
  }

  double? _variacaoPct(double anterior, double atual) {
    if (anterior <= 0) return null;
    return ((atual - anterior) / anterior) * 100;
  }
}