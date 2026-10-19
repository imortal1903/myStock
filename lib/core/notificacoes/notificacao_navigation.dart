import 'package:flutter/material.dart';

import '../../features/crud/repositories/produto_repository.dart';
import '../../features/crud/repositories/lote_repository.dart';
import '../../features/crud/viewmodels/home_viewmodel.dart' show ProdutoComLotes;
import '../../features/crud/views/produto_detail_page.dart';

/// Leva o usuário direto para a tela de detalhes do produto ao tocar em uma
/// notificação de validade (individual ou resumo do grupo).
abstract class NotificacaoNavigation {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static final _produtoRepo = ProdutoRepository();
  static final _loteRepo    = LoteRepository();

  /// Payload esperado: `"produto:<id>"` (ver `NotificacaoService._payload`).
  static Future<void> handlePayload(String? payload) async {
    if (payload == null || !payload.startsWith('produto:')) return;

    final produtoId = int.tryParse(payload.substring('produto:'.length));
    if (produtoId == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    try {
      final produto = await _produtoRepo.getById(produtoId);
      if (produto == null) return;

      final lotes = await _loteRepo.getByProduto(produtoId);

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProdutoDetailPage(
            item: ProdutoComLotes(produto: produto, lotes: lotes),
          ),
        ),
      );
    } catch (_) {
    }
  }
}