import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/home_viewmodel.dart' show ProdutoComLotes;
import '../viewmodels/produto_detail_viewmodel.dart';
import 'widgets/lote_tile.dart';
import 'update_page.dart';
import 'delete_page.dart';
import '../models/lote.dart';
import '../../analise/views/produto_analise_page.dart';
import '../../../core/extensions/quantidade_extensions.dart';
import '../../../core/theme/color_palette.dart';

class ProdutoDetailPage extends StatelessWidget {
  final ProdutoComLotes item;
  const ProdutoDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => ProdutoDetailViewModel(initial: item),
    child: const _ProdutoDetailView(),
  );
}

class _ProdutoDetailView extends StatelessWidget {
  const _ProdutoDetailView();

  /// Abre uma tela de edição/remoção e revalida o produto ao voltar.
  Future<void> _openAndRefresh(
      BuildContext context,
      Widget Function() builder,
      ) async {
    final vm = context.read<ProdutoDetailViewModel>();
    final navigator = Navigator.of(context);

    await navigator.push(MaterialPageRoute(builder: (_) => builder()));
    if (!context.mounted) return;

    final aindaExiste = await vm.refresh();
    if (!aindaExiste && context.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProdutoDetailViewModel>();
    final item = vm.item;
    final produto = item.produto;
    final descricao = produto.descricao?.trim() ?? '';
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: colors.textSecondary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(produto.nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.insights_outlined, color: colors.textSecondary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProdutoAnalisePage(
                  produtoId: produto.id!,
                  produtoNome: produto.nome,
                  produtoUnidade: produto.unidade,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: colors.textSecondary),
            onPressed: () =>
                _openAndRefresh(context, () => UpdatePage(produto: produto)),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.danger),
            onPressed: () =>
                _openAndRefresh(context, () => DeletePage(produto: produto)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (descricao.isNotEmpty) ...[
              Text(descricao,
                  style: TextStyle(
                    color: colors.textFaint,
                    fontSize: 14,
                    height: 1.5,
                  )),
              const SizedBox(height: 20),
            ],
            _InfoCard(item: item),
            const SizedBox(height: 16),
            _ResumoLotesCard(item: item),
            if (item.lotes.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Lotes',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 12),
              ...item.lotes.map(
                    (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LoteTile(
                    lote: l,
                    trailing: _StatusBadge(lote: l),
                    onTap: () => _openAndRefresh(
                      context,
                          () => UpdatePage(produto: produto, loteInicial: l),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Lote lote; // tipado! `dynamic` quebra as extensions do enum
  const _StatusBadge({required this.lote});

  @override
  Widget build(BuildContext context) {
    final cor = switch (lote.status) {
      LoteStatus.ativo    => context.colors.success,
      LoteStatus.esgotado => Colors.orangeAccent,
      LoteStatus.vencido  => context.colors.danger,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        lote.status.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ProdutoComLotes item;
  const _InfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = item.produto;
    final codigo = p.codigoBarras?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _InfoBlock(
              label: 'Estoque total',
              value: '${item.estoqueTotal.formatada} ${p.unidade}'),
          _InfoBlock(
              label: 'Média de preço',
              value: item.precoMedioValorFormatado,
              alignEnd: true),
        ]),
        if (codigo.isNotEmpty) ...[
          const SizedBox(height: 14),
          Divider(
              color: context.colors.onPrimaryMuted.withValues(alpha: 0.3),
              height: 1),
          const SizedBox(height: 14),
          _InfoBlock(label: 'Código de barras', value: codigo),
        ],
      ]),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label, value;
  final bool alignEnd;
  const _InfoBlock({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment:
    alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              color: context.colors.onPrimaryMuted, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
            color: context.colors.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          )),
    ],
  );
}

class _ResumoLotesCard extends StatelessWidget {
  final ProdutoComLotes item;
  const _ResumoLotesCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Resumo dos lotes',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          )),
      const SizedBox(height: 14),
      Row(children: [
        _ResumoBadge(
            label: 'Ativos',
            value: item.qtdAtivos,
            color: context.colors.success),
        const SizedBox(width: 10),
        _ResumoBadge(
            label: 'Esgotados',
            value: item.qtdEsgotados,
            color: Colors.orangeAccent),
        const SizedBox(width: 10),
        _ResumoBadge(
            label: 'Vencidos',
            value: item.qtdVencidos,
            color: context.colors.danger),
      ]),
    ]),
  );
}

class _ResumoBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ResumoBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$value',
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}