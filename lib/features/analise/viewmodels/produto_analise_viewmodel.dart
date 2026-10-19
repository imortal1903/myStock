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
  /// Independente da janela que a previsão escolheu internamente.
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
  /// recarregar.
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

  // Detalhe por lote de uma semana (ao tocar numa barra do gráfico)

  /// Chave = "semanasAtras" (mesma convenção de getVendasPorSemana: 0 =
  /// semana atual).
  final Map<int, List<VendaLoteSemana>> _detalhesPorSemana = {};
  final Set<int> _carregandoDetalheSemana = {};

  Map<int, List<VendaLoteSemana>> get detalhesPorSemana =>
      Map.unmodifiable(_detalhesPorSemana);

  bool carregandoDetalheSemana(int semanasAtras) =>
      _carregandoDetalheSemana.contains(semanasAtras);

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

        _detalhesPorSemana.clear();
      },
      onError: (e) => 'Erro ao carregar análise: $e',
    );
  }
}