import 'dart:async';

import '../services/previsao_estoque_service.dart';
import '../../crud/repositories/lote_repository.dart';
import '../../venda/repositories/venda_repository.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class ProdutoAnaliseViewModel extends BaseViewModel {
  final int produtoId;
  final PrevisaoEstoqueService _service;
  final VendaRepository _vendaRepo;
  final LoteRepository _loteRepo;

  /// Quantidade de semanas mostradas no mini-gráfico de tendência.
  /// Independente da janela que a previsão escolheu internamente — aqui é
  /// só para o usuário ver visualmente o padrão recente de vendas.
  static const int _semanasHistorico = 12;

  /// Recarrega a previsão periodicamente enquanto a tela está aberta, para
  /// que lotes que vencem (ou saem do estoque por outro motivo) apareçam
  /// atualizados sem precisar reabrir o app.
  static const Duration _intervaloAutoRefresh = Duration(minutes: 1);
  Timer? _autoRefreshTimer;

  ProdutoAnaliseViewModel({
    required this.produtoId,
    PrevisaoEstoqueService? service,
    VendaRepository? vendaRepo,
    LoteRepository? loteRepo,
  })  : _service = service ?? PrevisaoEstoqueService(),
        _vendaRepo = vendaRepo ?? VendaRepository(),
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

  /// Promove lotes vencidos (e registra a perda correspondente) antes de
  /// recarregar — sem isso, o giro de estoque e o risco de vencimento não
  /// refletem lotes que venceram desde a última carga.
  Future<void> _atualizarERecarregar() async {
    await _loteRepo.atualizarStatusVencidos();
    await carregar();
  }

  PrevisaoEstoque? _previsao;
  PrevisaoEstoque? get previsao => _previsao;

  List<LoteEmRisco> _lotesEmRisco = [];
  List<LoteEmRisco> get lotesEmRisco => List.unmodifiable(_lotesEmRisco);

  /// Índice 0 = semana mais recente.
  List<double> _historicoSemanal = [];
  List<double> get historicoSemanal => List.unmodifiable(_historicoSemanal);

  // ── Detalhe por lote de uma semana (ao tocar numa barra do gráfico) ──────

  /// Chave = "semanasAtras" (mesma convenção de getVendasPorSemana: 0 =
  /// semana atual). Carregado sob demanda, não de uma vez com o resto —
  /// a maioria das semanas nunca chega a ser expandida pelo usuário.
  final Map<int, List<VendaLoteSemana>> _detalhesPorSemana = {};
  final Set<int> _carregandoDetalheSemana = {};

  Map<int, List<VendaLoteSemana>> get detalhesPorSemana =>
      Map.unmodifiable(_detalhesPorSemana);

  bool carregandoDetalheSemana(int semanasAtras) =>
      _carregandoDetalheSemana.contains(semanasAtras);

  /// Busca (e cacheia) os lotes vendidos há [semanasAtras] semanas. Usa
  /// `safeNotify()` direto em vez de `run()`/`status` compartilhado — é um
  /// estado de carregamento paralelo e independente por semana (o usuário
  /// pode expandir mais de uma barra), não a carga principal da tela.
  Future<void> carregarDetalheSemana(int semanasAtras) async {
    if (_detalhesPorSemana.containsKey(semanasAtras) ||
        _carregandoDetalheSemana.contains(semanasAtras)) {
      return;
    }
    _carregandoDetalheSemana.add(semanasAtras);
    safeNotify();
    try {
      _detalhesPorSemana[semanasAtras] = await _vendaRepo
          .getVendasPorLoteNaSemana(produtoId, semanasAtras: semanasAtras);
    } catch (_) {
      _detalhesPorSemana[semanasAtras] = [];
    } finally {
      _carregandoDetalheSemana.remove(semanasAtras);
      safeNotify();
    }
  }

  Future<void> carregar() async {
    await run<void>(
          () async {
        _previsao = await _service.calcularPrevisao(produtoId);
        _lotesEmRisco = await _service.simularRiscoVencimento(produtoId);
        _historicoSemanal = await _vendaRepo.getVendasPorSemana(
          produtoId,
          semanas: _semanasHistorico,
        );
        // Os dados podem ter mudado desde a última carga (nova venda,
        // lote vencido, etc.) — descarta o cache de detalhe por semana
        // para não mostrar números desatualizados se o usuário reabrir
        // uma barra já expandida antes.
        _detalhesPorSemana.clear();
      },
      onError: (e) => 'Erro ao carregar análise: $e',
    );
  }
}