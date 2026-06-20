import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/home_viewmodel.dart';
import 'insert_page.dart';
import 'update_page.dart';
import 'delete_page.dart';
import 'notification_page.dart';
import '../../favorites/views/favorite_page.dart';
import '../../favorites/viewmodels/favorite_viewmodel.dart';
import '../../sales/views/sale_page.dart';
import '../../sales/viewmodels/sale_viewmodel.dart';
import '../../../core/theme/app_colors.dart';

// ─── Shell global ─────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  void _onNav(int i) {
    context.read<HomeViewModel>().selectNav(i);
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _index,
        children: [
          const _CrudContent(),
          ChangeNotifierProvider(create: (_) => FavoriteViewModel(), child: const FavoritesPage()),
          ChangeNotifierProvider(create: (_) => SaleViewModel(),     child: const SalesPage()),
        ],
      ),
      bottomNavigationBar: _BottomNav(current: _index, onTap: _onNav),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  static const _items = [
    (icon: Icons.home_outlined,            label: 'Início'),
    (icon: Icons.favorite_border_outlined,  label: 'Favoritos'),
    (icon: Icons.sell_outlined,             label: 'Vendas'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final sel = current == i;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_items[i].icon, color: sel ? AppColors.accent : Colors.white38, size: 24),
                const SizedBox(height: 4),
                Text(_items[i].label,
                    style: TextStyle(
                        color: sel ? AppColors.accent : Colors.white38,
                        fontSize: 11,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Conteúdo CRUD ────────────────────────────────────────────────────────────

class _CrudContent extends StatelessWidget {
  const _CrudContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(children: [
        const _TopBar(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.surface,
            onRefresh: () => context.read<HomeViewModel>().refresh(),
            child: const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(16, 0, 16, 200),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 16),
                _SearchBar(),
                SizedBox(height: 24),
                _QuickActions(),
                SizedBox(height: 24),
                _SectionHeader(title: 'Produtos em Estoque', action: 'Ver tudo'),
                SizedBox(height: 12),
                _ProductList(),
                SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.cloud_outlined, color: Colors.white, size: 20),
        ),
        const Expanded(
          child: Center(child: Text('Estoque',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
        ),
        Stack(children: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationPage())),
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          ),
          Positioned(right: 8, top: 8,
              child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle))),
        ]),
      ]),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar();
  @override State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Container(
          height: 46,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            onChanged: context.read<HomeViewModel>().onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Pesquisar produto...',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: () { _ctrl.clear(); context.read<HomeViewModel>().onSearchChanged(''); },
        child: const Row(children: [
          Text('Limpar', style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w500)),
          SizedBox(width: 4),
          Icon(Icons.close, color: AppColors.accent, size: 18),
        ]),
      ),
    ]);
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final vm = context.read<HomeViewModel>();
    return Row(children: [
      _ActionBtn(icon: Icons.add_outlined, label: 'Inserir',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InsertPage()))
              .then((_) => vm.refresh())),
      const SizedBox(width: 10),
      _ActionBtn(icon: Icons.edit_outlined, label: 'Editar',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const UpdatePage()))
              .then((_) => vm.refresh())),
      const SizedBox(width: 10),
      _ActionBtn(icon: Icons.delete_outline, label: 'Remover',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DeletePage()))
              .then((_) => vm.refresh())),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    ),
  );
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title, action;
  const _SectionHeader({required this.title, required this.action});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      Text(action, style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w500)),
    ],
  );
}

// ─── Product List ─────────────────────────────────────────────────────────────

class _ProductList extends StatelessWidget {
  const _ProductList();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();

    if (vm.isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(color: AppColors.accent),
      ));
    }
    if (vm.error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(vm.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
      ));
    }
    if (vm.items.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined, color: Colors.white12, size: 52),
          SizedBox(height: 12),
          Text('Nenhum produto encontrado.', style: TextStyle(color: Colors.white38, fontSize: 14)),
        ]),
      ));
    }

    return Column(children: vm.items.map((item) => _ProductCard(item: item)).toList());
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final ProdutoComLotes item;
  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final lote      = item.loteAtivo;
    final vencendo  = item.temLoteVencendo;
    final badgeCor  = lote != null && lote.estaVencido
        ? Colors.redAccent
        : vencendo ? Colors.orangeAccent : AppColors.accent;
    final badgeText = lote == null
        ? 'Sem lote ativo'
        : lote.estaVencido
        ? 'Vencido'
        : 'Val: ${lote.validadeFormatada}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: AppColors.primaryDark, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent, width: 1.5),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(item.produto.unidade, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 2),
            Text('Qtd: ${item.estoqueTotal}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(item.produto.nome,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeCor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badgeText,
                  style: TextStyle(color: badgeCor, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ]),
          if (item.produto.descricao != null) ...[
            const SizedBox(height: 4),
            Text(item.produto.descricao!, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 8),
          // Lotes
          Text('${item.lotes.length} lote${item.lotes.length != 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          if (lote != null) ...[
            const SizedBox(height: 2),
            Text(lote.precoCustoFormatado,
                style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ])),
      ]),
    );
  }
}