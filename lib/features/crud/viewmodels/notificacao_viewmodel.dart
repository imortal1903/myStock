import '../../../core/notificacoes/notificacao_config.dart';
import '../../../core/notificacoes/notificacao_service.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

import '../repositories/lote_repository.dart';
import '../../../core/notificacoes/notificacao_repository.dart';
import '../repositories/produto_repository.dart';

class NotificacaoViewModel extends BaseViewModel {
  final NotificacaoRepository _notifRepo;
  final ProdutoRepository _produtoRepo;
  final LoteRepository _loteRepo;

  NotificacaoViewModel({
    NotificacaoRepository? notifRepo,
    ProdutoRepository? produtoRepo,
    LoteRepository? loteRepo,
  })  : _notifRepo = notifRepo ?? NotificacaoRepository(),
        _produtoRepo = produtoRepo ?? ProdutoRepository(),
        _loteRepo = loteRepo ?? LoteRepository() {
    _load();
  }

  NotificacaoConfig _config = const NotificacaoConfig();

  NotificacaoConfig get config => _config;

  /// Alias mantido para compatibilidade com a UI existente. Antes disto
  /// era um bool próprio (`_loading`) mantido manualmente em paralelo a
  /// `isLoading` (herdado da base) — os dois podiam divergir, já que
  /// `_load()` nunca chamava `setStatus(ViewStatus.loading)`. Agora
  /// `_load()` passa por `run()`, então os dois sempre concordam.
  bool get loading => isLoading;
  bool get isSaving => isLoading;

  /// Aliases mantidos para compatibilidade com a UI existente.
  String? get error => errorMessage;
  bool get saved => status == ViewStatus.success;

  Future<void> _load() async {
    await run<void>(
          () async => _config = await _notifRepo.load(),
      onError: (e) => 'Erro ao carregar configurações: $e',
      markSuccess: false,
    );
  }

  void _updateConfig(NotificacaoConfig novo) {
    _config = novo;
    safeNotify();
  }

  void setAtivado(bool v) => _updateConfig(_config.copyWith(ativado: v));
  void setDiasAntes(int v) => _updateConfig(_config.copyWith(diasAntes: v));
  void setIntervalo(int horas) =>
      _updateConfig(_config.copyWith(intervaloHoras: horas));
  void setHorario(int hora, int minuto) =>
      _updateConfig(_config.copyWith(hora: hora, minuto: minuto));


  Future<void> salvar() async {
    setStatus(ViewStatus.loading);
    try {
      if (!await NotificacaoService.instance.requestAllPermissions()) {
        setStatus(
          ViewStatus.error,
          error: 'Permissão de alarme exato negada. Ative em '
              'Configurações → Aplicativos → Alarmes e lembretes.',
        );
        return;
      }

      await _notifRepo.save(_config);

      final lotes =
      await _loteRepo.getLotesProximosVencimento(_config.diasAntes + 1);

      final nomes = <int, String>{};
      for (final id in lotes.map((e) => e.produtoId).toSet()) {
        final produto = await _produtoRepo.getById(id);
        if (produto != null) nomes[id] = produto.nome;
      }

      await NotificacaoService.instance
          .scheduleForAllLotes(lotes, nomes, _config);

      setStatus(ViewStatus.success);
    } catch (e) {
      setStatus(ViewStatus.error, error: 'Erro ao salvar: $e');
    }
  }

  Future<void> testar() async {
    if (!await NotificacaoService.instance.requestAllPermissions()) {
      setStatus(
        ViewStatus.error,
        error: 'Permissão negada. Verifique as configurações do sistema.',
      );
      return;
    }
    await NotificacaoService.instance.showTest();
  }
}