import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lote.dart';
import '../models/produto.dart';
import '../viewmodels/delete_viewmodel.dart';
import 'widgets/lote_tile.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class DeletePage extends StatelessWidget {
  final Produto? produto;
  const DeletePage({super.key, this.produto});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => DeleteViewModel(initialProduto: produto),
    child: const _DeleteView(),
  );
}

/// Diálogo de confirmação destrutiva reaproveitado por lotes e produtos.
Future<bool> confirmDestructive(
    BuildContext ctx, {
      required String title,
      required Widget content,
      required String confirmLabel,
    }) async {
  final colors = ctx.colors;
  final ok = await showDialog<bool>(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          )),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child:
          Text('Cancelar', style: TextStyle(color: colors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogCtx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: Text(confirmLabel,
              style: TextStyle(color: colors.textPrimary)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<void> confirmDeleteProduto(
    BuildContext ctx, DeleteViewModel vm, Produto p) async {
  final colors = ctx.colors;
  final ok = await confirmDestructive(
    ctx,
    title: 'Remover produto',
    confirmLabel: 'Remover tudo',
    content: RichText(
      text: TextSpan(
        style: TextStyle(
            color: colors.textSecondary, fontSize: 14, height: 1.5),
        children: [
          const TextSpan(text: 'Isso removerá '),
          TextSpan(
            text: '"${p.nome}"',
            style: TextStyle(
                color: colors.textPrimary, fontWeight: FontWeight.w600),
          ),
          const TextSpan(text: ' do seu estoque.'),
        ],
      ),
    ),
  );
  if (ok && ctx.mounted) await vm.deleteProduto(p.id!);
}

class _DeleteView extends StatelessWidget {
  const _DeleteView();

  void _onBack(BuildContext context, DeleteViewModel vm) {
    if (vm.selectedProduto != null && !vm.abriuComProdutoEspecifico) {
      vm.clearSelection();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<DeleteViewModel>();

    if (vm.status == ViewStatus.success && vm.lastDeletedNome != null) {
      final nome = vm.lastDeletedNome!;
      final fechar = vm.abriuComProdutoEspecifico && vm.selectedProduto == null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"$nome" removido.'),
          backgroundColor: colors.primary,
        ));
        context.read<DeleteViewModel>().resetStatus();
        if (fechar && context.mounted) Navigator.pop(context);
      });
    }

    if (vm.status == ViewStatus.error && vm.errorMessage != null) {
      final msg = vm.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(msg), backgroundColor: colors.danger));
        context.read<DeleteViewModel>().resetStatus();
      });
    }

    final produto = vm.selectedProduto;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: colors.textSecondary, size: 18),
          onPressed: () => _onBack(context, vm),
        ),
        title: Text(produto?.nome ?? 'Remover Produto',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        centerTitle: true,
        actions: [
          if (produto != null)
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined,
                  color: Colors.redAccent),
              tooltip: 'Remover produto inteiro',
              onPressed: () => confirmDeleteProduto(context, vm, produto),
            ),
        ],
      ),
      body: produto == null ? _ProductList(vm: vm) : _LotesList(vm: vm),
    );
  }
}

// ── Lista de produtos ──

class _ProductList extends StatelessWidget {
  final DeleteViewModel vm;
  const _ProductList({required this.vm});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (vm.isLoading && vm.produtos.isEmpty) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }
    if (vm.produtos.isEmpty) {
      return Center(
          child: Text('Nenhum produto.',
              style: TextStyle(color: colors.textMuted)));
    }

    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Você pode remover o produto inteiro ou lotes específicos.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ),
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
              onDelete: () => confirmDeleteProduto(ctx, vm, p),
            );
          },
        ),
      ),
    ]);
  }
}

class _ProductTile extends StatelessWidget {
  final Produto produto;
  final VoidCallback onTapEdit;
  final VoidCallback onDelete;
  const _ProductTile({
    required this.produto,
    required this.onTapEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inventory_2_outlined,
              color: colors.onPrimary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: onTapEdit,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(produto.nome,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
                Text(produto.unidade,
                    style: TextStyle(color: colors.accent, fontSize: 12)),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.layers_outlined,
              color: colors.textMuted, size: 20),
          onPressed: onTapEdit,
          tooltip: 'Ver lotes',
        ),
        _DeleteIconButton(onPressed: onDelete),
      ]),
    );
  }
}

// ── Lotes do produto ──

class _LotesList extends StatelessWidget {
  final DeleteViewModel vm;
  const _LotesList({required this.vm});

  Future<void> _confirmDeleteLote(
      BuildContext ctx, DeleteViewModel vm, Lote l) async {
    final label = l.numeroLote ?? 'Lote #${l.id}';
    final ok = await confirmDestructive(
      ctx,
      title: 'Remover lote',
      confirmLabel: 'Remover',
      content: Text('Remover "$label" permanentemente?',
          style: TextStyle(color: ctx.colors.textSecondary, fontSize: 14)),
    );
    if (ok && ctx.mounted) await vm.deleteLote(l.id!);
  }

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading && vm.lotes.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: context.colors.accent));
    }
    if (vm.lotes.isEmpty) {
      return Center(
        child: Text('Nenhum lote cadastrado.',
            style: TextStyle(color: context.colors.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vm.lotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final lote = vm.lotes[i];
        return LoteTile(
          lote: lote,
          selected: lote.estaVencido,
          trailing:
          _DeleteIconButton(onPressed: () => _confirmDeleteLote(ctx, vm, lote)),
        );
      },
    );
  }
}

class _DeleteIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _DeleteIconButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.delete_outline,
        color: Colors.redAccent, size: 20),
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}