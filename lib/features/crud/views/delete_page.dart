import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lote.dart';
import '../models/produto.dart';
import '../viewmodels/delete_viewmodel.dart';
import '../../../core/theme/app_colors.dart';

class DeletePage extends StatelessWidget {
  const DeletePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeleteViewModel(),
      child: const _DeleteView(),
    );
  }
}

class _DeleteView extends StatelessWidget {
  const _DeleteView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeleteViewModel>();

    if (vm.status == DeleteStatus.success && vm.lastDeletedNome != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${vm.lastDeletedNome}" removido.'),
          backgroundColor: context.colors.primary,
        ));
        context.read<DeleteViewModel>().resetStatus();
      });
    }

    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.surface, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.colors.textSecondary, size: 18),
          onPressed: () {
            if (vm.selectedProduto != null) {
              context.read<DeleteViewModel>().clearSelection();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          vm.selectedProduto == null ? 'Remover Produto' : vm.selectedProduto!.nome,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: vm.selectedProduto == null
          ? _ProductList(vm: vm)
          : _ProdutoDetail(vm: vm),
    );
  }
}

// ── Lista de produtos ─────────────────────────────────────────────────────────

class _ProductList extends StatelessWidget {
  final DeleteViewModel vm;
  const _ProductList({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading && vm.produtos.isEmpty) {
      return Center(child: CircularProgressIndicator(color: context.colors.accent));
    }
    if (vm.produtos.isEmpty) {
      return Center(child: Text('Nenhum produto.', style: TextStyle(color: context.colors.textMuted)));
    }
    return Column(children: [
      // Banner de aviso
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('Você pode remover o produto inteiro ou lotes específicos.',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 12))),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: vm.produtos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final p = vm.produtos[i];
            return _ProductTile(
              produto: p,
              onTapEdit: () => vm.selectProduto(p),
              onDelete: () => _confirmDeleteProduto(ctx, vm, p),
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _confirmDeleteProduto(
      BuildContext ctx, DeleteViewModel vm, Produto p) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remover produto', style: TextStyle(color: ctx.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        content: RichText(text: TextSpan(
          style: TextStyle(color: ctx.colors.textSecondary, fontSize: 14, height: 1.5),
          children: [
            const TextSpan(text: 'Isso removerá '),
            TextSpan(text: '"${p.nome}"', style: TextStyle(color: ctx.colors.textPrimary, fontWeight: FontWeight.w600)),
            const TextSpan(text: ' e todos os seus lotes permanentemente.'),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: TextStyle(color: ctx.colors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: Text('Remover tudo', style: TextStyle(color: ctx.colors.textPrimary)),
          ),
        ],
      ),
    );
    if (ok == true && ctx.mounted) await vm.deleteProduto(p.id!);
  }
}

class _ProductTile extends StatelessWidget {
  final Produto produto;
  final VoidCallback onTapEdit;
  final VoidCallback onDelete;
  const _ProductTile({required this.produto, required this.onTapEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.divider)),
    child: Row(children: [
      Container(width: 42, height: 42,
          decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.inventory_2_outlined, color: context.colors.onPrimary, size: 20)),
      const SizedBox(width: 14),
      Expanded(child: GestureDetector(
        onTap: onTapEdit,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(produto.nome, style: TextStyle(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          Text(produto.unidade, style: TextStyle(color: context.colors.accent, fontSize: 12)),
        ]),
      )),
      // Ver lotes
      IconButton(
        icon: Icon(Icons.layers_outlined, color: context.colors.textMuted, size: 20),
        onPressed: onTapEdit,
        tooltip: 'Ver lotes',
      ),
      // Deletar produto inteiro
      IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
        onPressed: onDelete,
        style: IconButton.styleFrom(
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );
}

// ── Detalhe: lotes do produto ─────────────────────────────────────────────────

class _ProdutoDetail extends StatelessWidget {
  final DeleteViewModel vm;
  const _ProdutoDetail({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.lotes.isEmpty) {
      return Center(child: Text('Nenhum lote cadastrado.',
          style: TextStyle(color: context.colors.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vm.lotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _LoteTile(
        lote: vm.lotes[i],
        onDelete: () => _confirmDeleteLote(ctx, vm, vm.lotes[i]),
      ),
    );
  }

  Future<void> _confirmDeleteLote(
      BuildContext ctx, DeleteViewModel vm, Lote l) async {
    final label = l.numeroLote ?? 'Lote #${l.id}';
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remover lote', style: TextStyle(color: ctx.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text('Remover "$label" permanentemente?',
            style: TextStyle(color: ctx.colors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: TextStyle(color: ctx.colors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: Text('Remover', style: TextStyle(color: ctx.colors.textPrimary)),
          ),
        ],
      ),
    );
    if (ok == true && ctx.mounted) await vm.deleteLote(l.id!);
  }
}

class _LoteTile extends StatelessWidget {
  final Lote lote;
  final VoidCallback onDelete;
  const _LoteTile({required this.lote, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cor = lote.estaVencido ? Colors.redAccent : context.colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.divider)),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(width: 46, height: 46,
              decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.layers_outlined, color: context.colors.onPrimary, size: 22)),
          if (lote.estaVencido)
            Positioned(right: -4, top: -4,
                child: Container(width: 14, height: 14,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: Icon(Icons.priority_high, color: context.colors.onPrimary, size: 10))),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lote.numeroLote ?? 'Lote #${lote.id}',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Qtd: ${lote.quantidade} · ${lote.precoCustoFormatado}',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
          Row(children: [
            Icon(lote.estaVencido ? Icons.cancel_outlined : Icons.check_circle_outline,
                color: cor, size: 13),
            const SizedBox(width: 4),
            Text(
              lote.estaVencido ? 'Vencido em ${lote.validadeFormatada}' : 'Val: ${lote.validadeFormatada}',
              style: TextStyle(color: cor, fontSize: 11),
            ),
          ]),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
          onPressed: onDelete,
          style: IconButton.styleFrom(
            backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }
}