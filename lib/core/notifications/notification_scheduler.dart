import 'package:flutter/foundation.dart';
import '../../features/crud/models/notificacao.dart';
import '../../features/crud/repositories/lote_repository.dart';
import '../../features/crud/repositories/notificacao_repository.dart';
import '../../features/crud/repositories/produto_repository.dart';
import '../notifications/notification_service.dart';

/// Reagenda notificações locais e registra alertas no banco
/// após qualquer operação CRUD que afete lotes.
abstract class NotificationScheduler {
  static final _loteRepo    = LoteRepository();
  static final _produtoRepo = ProdutoRepository();
  static final _notifRepo   = NotificacaoRepository();
  static final _dbNotifRepo = NotificacaoRepository();
  static bool _running = false;

  static Future<void> reschedule() async {
    if(_running)return;
    _running = true;
    try {
      // 1. Atualiza status de lotes vencidos no banco
      await _loteRepo.atualizarStatusVencidos();

      // 2. Carrega config e todos os lotes ativos
      final config = await _notifRepo.load();
      final lotes  = await _loteRepo.getLotesProximosVencimento(
          config.diasAntes + 1);

      // 3. Busca nomes dos produtos para as mensagens
      final produtoIds = lotes.map((l) => l.produtoId).toSet();
      final Map<int, String> nomes = {};
      for (final id in produtoIds) {
        final p = await _produtoRepo.getById(id);
        if (p != null) nomes[id] = p.nome;
      }

      // 4. Registra notificações no banco (para o sino da home)
      await _dbNotifRepo.deleteAutomaticas();

      for (final lote in lotes) {
        final nome = nomes[lote.produtoId] ?? 'Produto';

        final tipo = lote.estaVencido
            ? NotificacaoTipo.produtoVencido
            : NotificacaoTipo.validadeProxima;

        final msg = lote.estaVencido
            ? '$nome: lote ${lote.numeroLote ?? '#${lote.id}'} está vencido'
            : '$nome: lote ${lote.numeroLote ?? '#${lote.id}'} '
            'vence em ${lote.diasParaVencer} dia(s)';

        final existe = await _dbNotifRepo.existe(
          loteId: lote.id!,
          tipo: tipo,
        );

        if (!existe) {
          await _dbNotifRepo.insert(
            Notificacao(
              tipo: tipo,
              produtoId: lote.produtoId,
              loteId: lote.id,
              mensagem: msg,
              criadoEm: DateTime.now(),
            ),
          );
        }
      }

      // 5. Agenda notificações locais (push) pelos lotes
      await NotificationService.instance
          .scheduleForAllLotes(lotes, nomes, config);
    } catch (e, s) {
      debugPrint('Erro ao reagendar notificações: $e');
      debugPrintStack(stackTrace: s);
    } finally {
      _running = false;
    }
  }
}