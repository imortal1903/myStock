import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../crud/models/produto.dart';
import '../viewmodels/favorite_viewmodel.dart';
import '../../../core/theme/app_colors.dart';

// FavoritesPage é um widget de CONTEÚDO (sem Scaffold).
// O Scaffold vem do shell em home_page.dart.

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoriteViewModel>();

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
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.favorite_border_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Favoritos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (!vm.isEmpty)
                  Text(
                    '${vm.favoritos.length} item${vm.favoritos.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppColors.accent, fontSize: 13),
                  ),
              ],
            ),
          ),

          // ── Conteúdo ──────────────────────────────────────────────────────
          Expanded(
            child: vm.isEmpty
                ? const _EmptyFavorites()
                : _FavoritesList(produtos: vm.favoritos),
          ),
        ],
      ),
    );
  }
}

// ─── Lista de favoritos ───────────────────────────────────────────────────────

class _FavoritesList extends StatelessWidget {
  final List<Produto> produtos;
  const _FavoritesList({required this.produtos});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: produtos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _FavoriteCard(produto: produtos[i]),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Produto produto;
  const _FavoriteCard({required this.produto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(produto.nome,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite,
                color: AppColors.accent, size: 20),
            onPressed: () =>
                context.read<FavoriteViewModel>().toggle(produto),
          ),
        ],
      ),
    );
  }
}

// ─── Estado vazio ─────────────────────────────────────────────────────────────

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.favorite_border_outlined,
            color: Colors.white12, size: 56),
        SizedBox(height: 12),
        Text('Nenhum favorito ainda',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
        SizedBox(height: 4),
        Text('Marque produtos como favoritos para vê-los aqui.',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      ]),
    );
  }
}