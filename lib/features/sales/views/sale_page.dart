import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/sale_viewmodel.dart';
import '../../../core/theme/app_colors.dart';

// SalesPage é um widget de CONTEÚDO (sem Scaffold).
// O Scaffold vem do shell em home_page.dart.

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleViewModel>();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: DarkBlueColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sell_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Vendas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Resumo ───────────────────────────────────────────────────────
          if (!vm.isEmpty) _SummaryCard(vm: vm),

          // ── Conteúdo ─────────────────────────────────────────────────────
          Expanded(
            child: vm.isEmpty
                ? const _EmptySales()
                : _SalesList(vm: vm),
          ),
        ],
      ),
    );
  }
}

// ─── Cartão de resumo ─────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final SaleViewModel vm;
  const _SummaryCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DarkBlueColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            label: 'Total vendido',
            value: 'R\$ ${vm.totalGeral.toStringAsFixed(2)}',
          ),
          Container(
              width: 1, height: 32, color: Colors.white24),
          _SummaryItem(
            label: 'Itens vendidos',
            value: '${vm.totalItens}',
          ),
          Container(
              width: 1, height: 32, color: Colors.white24),
          _SummaryItem(
            label: 'Nº de vendas',
            value: '${vm.vendas.length}',
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              color: DarkBlueColors.accent,
              fontSize: 16,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}

// ─── Lista de vendas ──────────────────────────────────────────────────────────

class _SalesList extends StatelessWidget {
  final SaleViewModel vm;
  const _SalesList({required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: vm.vendas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _SaleCard(
        sale: vm.vendas[i],
        onRemove: () => vm.removerVenda(vm.vendas[i].id),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final Sale        sale;
  final VoidCallback onRemove;
  const _SaleCard({required this.sale, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DarkBlueColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: DarkBlueColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.produto.nome,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${sale.quantidade} ${sale.produto.unidade} · '
                      'R\$ ${sale.totalPago.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: DarkBlueColors.accent, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(sale.dataFormatada,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.white24, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ─── Estado vazio ─────────────────────────────────────────────────────────────

class _EmptySales extends StatelessWidget {
  const _EmptySales();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.sell_outlined, color: Colors.white12, size: 56),
        SizedBox(height: 12),
        Text('Nenhuma venda registrada',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
        SizedBox(height: 4),
        Text('As vendas registradas aparecerão aqui.',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      ]),
    );
  }
}