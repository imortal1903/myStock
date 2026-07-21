import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/home_viewmodel.dart';
import 'insert_page.dart';
import 'update_page.dart';
import 'delete_page.dart';
import 'notification_page.dart';
import 'categoria_page.dart';
//import '../../analytics/views/analytics_page.dart';
//import '../../analytics/viewmodels/analytics_viewmodel.dart';
import '../../sales/views/sale_page.dart';
import '../../sales/viewmodels/sale_viewmodel.dart';
import '../../../core/theme/color_palette.dart';
import '../../settings/views/settings_page.dart';

// ─── Shell global ─────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  late final SaleViewModel _saleViewModel = SaleViewModel();
  //late final AnalyticsViewModel _analyticsViewModel = AnalyticsViewModel();

  late final List<_Tab> _tabs = [
    _Tab(
      child: const _CrudContent(),
      onEnter: () => context.read<HomeViewModel>().refresh(),
    ),
    /*_Tab(
      child: ChangeNotifierProvider.value(value: _analyticsViewModel, child: const AnalyticsPage()),
      onEnter: _analyticsViewModel.refresh,
    ),*/
    _Tab(
      child: ChangeNotifierProvider.value(value: _saleViewModel, child: const SalesPage()),
      onEnter: _saleViewModel.refresh,
    ),
  ];

  void _onNav(int i) {
    context.read<HomeViewModel>().selectNav(i);
    _tabs[i].onEnter?.call();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: IndexedStack(
        index: _index,
        children: _tabs.map((t) => t.child).toList(),
      ),
      bottomNavigationBar: _BottomNav(current: _index, onTap: _onNav),
    );
  }
}

class _Tab {
  final Widget child;
  final VoidCallback? onEnter;
  const _Tab({required this.child, this.onEnter});
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  static const _items = [
    (icon: Icons.home_outlined,             label: 'Início'),
    (icon: Icons.sell_outlined,             label: 'Vendas'),
    (icon: Icons.analytics_outlined,        label: 'Painel')
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                color: sel ? context.colors.accent.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_items[i].icon, color: sel ? context.colors.accent : context.colors.textFaint, size: 24),
                const SizedBox(height: 4),
                Text(_items[i].label,
                    style: TextStyle(
                        color: sel ? context.colors.accent : context.colors.textFaint,
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
            color: context.colors.accent,
            backgroundColor: context.colors.surface,
            onRefresh: () => context.read<HomeViewModel>().refresh(),
            child: const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(16, 0, 16, 200),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 16),
                _SearchSection(),
                SizedBox(height: 24),
                _QuickActions(),
                SizedBox(height: 24),
                _SectionHeader(title: 'Produtos', action: 'Ver tudo'),
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
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsPage())),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.settings_outlined, color: context.colors.onPrimary, size: 20),
          ),
        ),
        Expanded(
          child: Center(child: Text('Estoque',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
        ),
        Stack(children: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationPage())),
            icon: Icon(Icons.notifications_outlined, color: context.colors.textPrimary),
          ),
        ]),
      ]),
    );
  }
}

// ─── Busca + Filtro por categoria ──────────────────────────────────────────────

class _SearchSection extends StatefulWidget {
  const _SearchSection();
  @override State<_SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<_SearchSection> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _clear(HomeViewModel vm) {
    _ctrl.clear();
    vm.onSearchChanged('');
    vm.filtrarPorCategoria(null);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final temFiltroAtivo = _ctrl.text.isNotEmpty || vm.categoriaFiltroId != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
              onChanged: vm.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Pesquisar produto...',
                hintStyle: TextStyle(color: context.colors.textFaint, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: context.colors.textFaint, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: temFiltroAtivo ? () => _clear(vm) : null,
          child: Row(children: [
            Text('Limpar',
                style: TextStyle(
                  color: temFiltroAtivo ? context.colors.accent : context.colors.textFaint,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(width: 4),
            Icon(Icons.close,
                color: temFiltroAtivo ? context.colors.accent : context.colors.textFaint, size: 18),
          ]),
        ),
      ]),
      if (vm.categorias.isNotEmpty) ...[
        const SizedBox(height: 12),
        _CategoryChips(vm: vm),
      ],
    ]);
  }
}

class _CategoryChips extends StatelessWidget {
  final HomeViewModel vm;
  const _CategoryChips({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: vm.categorias.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _CategoryChip(
              label: 'Todas',
              selected: vm.categoriaFiltroId == null,
              onTap: () => vm.filtrarPorCategoria(null),
            );
          }
          final categoria = vm.categorias[i - 1];
          return _CategoryChip(
            label: categoria.nome,
            selected: vm.categoriaFiltroId == categoria.id,
            onTap: () => vm.filtrarPorCategoria(categoria.id),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.colors.accent : context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? context.colors.accent : context.colors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1A1A2E) : context.colors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
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
      const SizedBox(width: 10),
      _ActionBtn(icon: Icons.category_outlined, label: 'Categorias',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CategoriaPage()))
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
        decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: context.colors.onPrimary, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: context.colors.onPrimarySecondary, fontSize: 12)),
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
      Text(title, style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      Text(action, style: TextStyle(color: context.colors.accent, fontSize: 13, fontWeight: FontWeight.w500)),
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
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(color: context.colors.accent),
      ));
    }
    if (vm.error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(vm.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
      ));
    }
    if (vm.items.isEmpty) {
      final categoria = vm.categoriaFiltroSelecionada;
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined, color: context.colors.divider, size: 52),
          const SizedBox(height: 12),
          Text(
            categoria != null
                ? 'Nenhum produto em "${categoria.nome}".'
                : 'Nenhum produto encontrado.',
            style: TextStyle(color: context.colors.textFaint, fontSize: 14),
            textAlign: TextAlign.center,
          ),
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
        : vencendo ? Colors.orangeAccent : context.colors.secondary;
    final badgeText = lote == null
        ? 'Sem lote ativo'
        : lote.estaVencido
        ? 'Vencido'
        : 'Val: ${lote.validadeFormatada}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: context.colors.primaryDark, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.accent, width: 1.5),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inventory_2_outlined, color: context.colors.onPrimary, size: 28),
            const SizedBox(height: 4),
            Text(item.produto.unidade, style: TextStyle(color: context.colors.onPrimarySecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text('Qtd: ${item.estoqueTotal}',
                style: TextStyle(color: context.colors.onPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(item.produto.nome,
                style: TextStyle(color: context.colors.onPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
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
                style: TextStyle(color: context.colors.onPrimarySecondary, fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 8),
          // Lotes
          Text('${item.lotes.length} lote${item.lotes.length != 1 ? 's' : ''}',
              style: TextStyle(color: context.colors.onPrimaryMuted, fontSize: 11)),
          if (lote != null) ...[
            const SizedBox(height: 2),
            Text(lote.precoCustoFormatado,
                style: TextStyle(color: context.colors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ])),
      ]),
    );
  }
}