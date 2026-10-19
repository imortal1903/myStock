import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/home_viewmodel.dart';
import 'insert_page.dart';
import 'notificacao_page.dart';
import 'categoria_page.dart';
import 'produto_detail_page.dart';
import '../../venda/views/venda_page.dart';
import '../../venda/viewmodels/venda_viewmodel.dart';
import '../../analise/viewmodels/analise_viewmodel.dart';
import '../../analise/views/analise_page.dart';
import '../../../core/extensions/quantidade_extensions.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/promocoes/sugestao_promocional_service.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../config/views/config_page.dart';
import '../repositories/produto_repository.dart';
import '../repositories/lote_repository.dart';

// Shell global
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  late final VendaViewModel _vendaViewModel = VendaViewModel();
  late final AnaliseViewModel _analiseViewModel = AnaliseViewModel();
  late final List<_Tab> _tabs = [
    _Tab(
      icon: Icons.home_outlined,
      label: 'Início',
      builder: () => const _CrudContent(),
      onEnter: () => context.read<HomeViewModel>().refresh(),
    ),
    _Tab(
      icon: Icons.sell_outlined,
      label: 'Vendas',
      builder: () => ChangeNotifierProvider.value(
        value: _vendaViewModel,
        child: const VendasPage(),
      ),
      onEnter: _vendaViewModel.refresh,
    ),
    _Tab(
      icon: Icons.analytics_outlined,
      label: 'Painel',
      builder: () => ChangeNotifierProvider.value(
          value: _analiseViewModel, child: const AnalisePage()),
      onEnter: _analiseViewModel.carregar,
    ),
  ];

  late final List<Widget> _children = _tabs.map((t) => t.builder()).toList();

  void _onNav(int i) {
    if (i == _index) return;
    context.read<HomeViewModel>().selectNav(i);
    _tabs[i].onEnter?.call();
    setState(() => _index = i);
  }

  @override
  void dispose() {
    _vendaViewModel.dispose();
    _analiseViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.bg,
    body: IndexedStack(index: _index, children: _children),
    bottomNavigationBar:
    _BottomNav(tabs: _tabs, current: _index, onTap: _onNav),
  );
}

class _Tab {
  final IconData icon;
  final String label;
  final Widget Function() builder;
  final VoidCallback? onEnter;
  const _Tab({
    required this.icon,
    required this.label,
    required this.builder,
    this.onEnter,
  });
}

// Bottom Nav
class _BottomNav extends StatelessWidget {
  final List<_Tab> tabs;
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({
    required this.tabs,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (i) {
          final sel = current == i;
          final cor = sel ? colors.accent : colors.textFaint;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: sel
                    ? colors.accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(tabs[i].icon, color: cor, size: 24),
                const SizedBox(height: 4),
                Text(tabs[i].label,
                    style: TextStyle(
                      color: cor,
                      fontSize: 11,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    )),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

// Conteúdo CRUD
class _CrudContent extends StatelessWidget {
  const _CrudContent();

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(children: [
      const _TopBar(),
      Expanded(
        child: RefreshIndicator(
          color: context.colors.accent,
          backgroundColor: context.colors.surface,
          onRefresh: () => context.read<HomeViewModel>().refresh(),
          child: const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(16, 0, 16, 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                _SearchSection(),
                SizedBox(height: 24),
                _QuickActions(),
                SizedBox(height: 24),
                _SugestoesPromocionaisCard(),
                _SectionHeader(title: 'Produtos'),
                SizedBox(height: 12),
                _ProdutoList(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ]),
  );
}

// Top Bar
class _TopBar extends StatelessWidget {
  const _TopBar();

  void _go(BuildContext context, Widget page) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => page),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(alignment: Alignment.center, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 96),
          child: Text('Estoque',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              strutStyle: const StrutStyle(height: 1, forceStrutHeight: true),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              )),
        ),
        Row(children: [
          GestureDetector(
            onTap: () => _go(context, const ConfigPage()),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.settings_outlined,
                  color: colors.onPrimary, size: 20),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _go(context, const NotificacaoPage()),
            icon: Icon(Icons.notifications_outlined, color: colors.textPrimary),
          ),
        ]),
      ]),
    );
  }
}

// Busca + Filtro por categoria
class _SearchSection extends StatefulWidget {
  const _SearchSection();
  @override
  State<_SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<_SearchSection> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _clear(HomeViewModel vm) {
    _ctrl.clear();
    vm.onSearchChanged('');
    vm.filtrarPorCategoria(null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<HomeViewModel>();
    final temFiltro = vm.query.isNotEmpty || vm.categoriaFiltroId != null;
    final corLimpar = temFiltro ? colors.accent : colors.textFaint;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppSearchField(
        controller: _ctrl,
        onChanged: vm.onSearchChanged,
        hintText: 'Pesquisar produto...',
        trailing: GestureDetector(
          onTap: temFiltro ? () => _clear(vm) : null,
          child: Row(children: [
            Text('Limpar',
                style: TextStyle(
                  color: corLimpar,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(width: 4),
            Icon(Icons.close, color: corLimpar, size: 18),
          ]),
        ),
      ),
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
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: vm.categorias.length + 1,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        if (i == 0) {
          return _CategoryChip(
            label: 'Todas',
            selected: vm.categoriaFiltroId == null,
            onTap: () => vm.filtrarPorCategoria(null),
          );
        }
        final c = vm.categorias[i - 1];
        return _CategoryChip(
          label: c.nome,
          selected: vm.categoriaFiltroId == c.id,
          onTap: () => vm.filtrarPorCategoria(c.id),
        );
      },
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(18),
          border:
          Border.all(color: selected ? colors.accent : colors.divider),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF1A1A2E)
                  : colors.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            )),
      ),
    );
  }
}

// Quick Actions
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final vm = context.read<HomeViewModel>();

    Future<void> abrir(Widget page) async {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => page));
      await vm.refresh();
    }

    return Row(children: [
      _ActionBtn(
        icon: Icons.add_outlined,
        label: 'Inserir',
        onTap: () => abrir(const InsertPage()),
      ),
      const SizedBox(width: 10),
      _ActionBtn(
        icon: Icons.category_outlined,
        label: 'Categorias',
        onTap: () => abrir(const CategoriaPage()),
      ),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: context.colors.onPrimary, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: context.colors.onPrimarySecondary,
                  fontSize: 12)),
        ]),
      ),
    ),
  );
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(title,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ));
}

// Produto List
class _ProdutoList extends StatelessWidget {
  const _ProdutoList();

  Widget _centered(Widget child) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();

    if (vm.isLoading) {
      return _centered(
          CircularProgressIndicator(color: context.colors.accent));
    }
    if (vm.errorMessage != null) {
      return _centered(Text(vm.errorMessage!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 14)));
    }
    if (vm.items.isEmpty) {
      final categoria = vm.categoriaFiltroSelecionada;
      return _centered(
        Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined,
              color: context.colors.divider, size: 52),
          const SizedBox(height: 12),
          Text(
            categoria != null
                ? 'Nenhum produto em "${categoria.nome}".'
                : 'Nenhum produto encontrado.',
            style: TextStyle(color: context.colors.textFaint, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return Column(
      children: vm.items.map((item) => _ProdutoCard(item: item)).toList(),
    );
  }
}

// Product Card
class _ProdutoCard extends StatelessWidget {
  final ProdutoComLotes item;
  const _ProdutoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final loteProximo = item.loteAtivo;
    final descricao = item.produto.descricao?.trim() ?? '';

    final valCor = loteProximo == null
        ? colors.onPrimaryMuted
        : item.temLoteVencendo
        ? Colors.orangeAccent
        : colors.success;
    final valText = loteProximo == null
        ? 'Sem lote ativo'
        : 'Val: ${loteProximo.validadeFormatada}';

    return GestureDetector(
      onTap: () async {
        final vm = context.read<HomeViewModel>();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProdutoDetailPage(item: item)),
        );
        await vm.refresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colors.primaryDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.accent, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    color: colors.onPrimary, size: 28),
                const SizedBox(height: 4),
                Text(item.produto.unidade,
                    style: TextStyle(
                        color: colors.onPrimarySecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text('Qtd: ${item.estoqueTotal.formatada}',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(item.produto.nome,
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: valCor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(valText,
                            style: TextStyle(
                              color: valCor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ),
                  if (descricao.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onPrimarySecondary,
                          fontSize: 12,
                          height: 1.4,
                        )),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.lotes.length} lote'
                            '${item.lotes.length != 1 ? 's' : ''}',
                        style: TextStyle(
                            color: colors.onPrimaryMuted, fontSize: 11),
                      ),
                      Flexible(
                        child: Text(item.precoMedioFormatado,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// Sugestões promocionais
class _SugestoesPromocionaisCard extends StatefulWidget {
  const _SugestoesPromocionaisCard();

  @override
  State<_SugestoesPromocionaisCard> createState() =>
      _SugestoesPromocionaisCardState();
}

class _SugestoesPromocionaisCardState
    extends State<_SugestoesPromocionaisCard> {
  final _service = SugestaoPromocionalService();
  List<SugestaoPromocional>? _sugestoes;
  late final HomeViewModel _homeViewModel;

  @override
  void initState() {
    super.initState();
    _homeViewModel = context.read<HomeViewModel>();
    _homeViewModel.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() {
    _homeViewModel.removeListener(_carregar);
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final sugestoes = await _service.gerarSugestoes();
      if (mounted) setState(() => _sugestoes = sugestoes);
    } catch (_) {
      if (mounted) setState(() => _sugestoes = const []);
    }
  }

  Future<void> _abrirProduto(BuildContext context, int produtoId) async {
    final produto = await ProdutoRepository().getById(produtoId);
    if (produto == null || !context.mounted) return;

    final lotes = await LoteRepository().getByProduto(produtoId);
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoDetailPage(
          item: ProdutoComLotes(produto: produto, lotes: lotes),
        ),
      ),
    );
  }

  void _abrirLista(BuildContext context, List<SugestaoPromocional> sugestoes) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _SugestoesSheet(
        sugestoes: sugestoes,
        onAbrir: (produtoId) {
          Navigator.pop(sheetCtx);
          _abrirProduto(context, produtoId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes = _sugestoes;
    if (sugestoes == null || sugestoes.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    int contar(MotivoSugestao m) =>
        sugestoes.where((s) => s.motivo == m).length;
    final vencendo = contar(MotivoSugestao.vencimentoProximo);
    final estoqueBaixo = contar(MotivoSugestao.estoqueBaixo);
    final baixaSaida = contar(MotivoSugestao.baixaRotatividade);
    final produtos = sugestoes.map((s) => s.produtoId).toSet().length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () => _abrirLista(context, sugestoes),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.campaign_outlined,
                  color: colors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sugestões',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    produtos == 1
                        ? '1 produto precisa de atenção'
                        : '$produtos produtos precisam de atenção',
                    style: TextStyle(color: colors.textFaint, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (vencendo > 0)
                      _ContagemChip(
                        icone: Icons.schedule,
                        texto: '$vencendo vencendo',
                        cor: Colors.orangeAccent,
                      ),
                    if (estoqueBaixo > 0)
                      _ContagemChip(
                        icone: Icons.production_quantity_limits,
                        texto: '$estoqueBaixo estoque baixo',
                        cor: colors.danger,
                      ),
                    if (baixaSaida > 0)
                      _ContagemChip(
                        icone: Icons.trending_down,
                        texto: '$baixaSaida baixa saída',
                        cor: colors.accent,
                      ),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textGhost, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _ContagemChip extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color cor;
  const _ContagemChip({
    required this.icone,
    required this.texto,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icone, color: cor, size: 13),
      const SizedBox(width: 4),
      Text(texto,
          style: TextStyle(
            color: cor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          )),
    ]),
  );
}

/// Lista completa das sugestões, agrupada por motivo.
class _SugestoesSheet extends StatelessWidget {
  final List<SugestaoPromocional> sugestoes;
  final ValueChanged<int> onAbrir;
  const _SugestoesSheet({required this.sugestoes, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final grupos = <(MotivoSugestao, String, IconData, Color)>[
      (
      MotivoSugestao.vencimentoProximo,
      'Vencimento próximo',
      Icons.schedule,
      Colors.orangeAccent,
      ),
      (
      MotivoSugestao.estoqueBaixo,
      'Estoque baixo',
      Icons.production_quantity_limits,
      colors.danger,
      ),
      (
      MotivoSugestao.baixaRotatividade,
      'Baixa saída',
      Icons.trending_down,
      colors.accent,
      ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Sugestões',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
          for (final (motivo, titulo, icone, cor) in grupos)
            ..._grupo(
              context,
              sugestoes.where((s) => s.motivo == motivo).toList(),
              titulo,
              icone,
              cor,
            ),
        ],
      ),
    );
  }

  List<Widget> _grupo(
      BuildContext context,
      List<SugestaoPromocional> itens,
      String titulo,
      IconData icone,
      Color cor,
      ) {
    if (itens.isEmpty) return const [];
    final colors = context.colors;

    return [
      const SizedBox(height: 18),
      Row(children: [
        Icon(icone, color: cor, size: 18),
        const SizedBox(width: 6),
        Text('$titulo (${itens.length})',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
      ]),
      const SizedBox(height: 4),
      Text(itens.first.texto,
          style: TextStyle(color: colors.textFaint, fontSize: 12, height: 1.3)),
      const SizedBox(height: 8),
      for (final s in itens)
        InkWell(
          onTap: () => onAbrir(s.produtoId),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.produtoNome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                    )),
              ),
              if (s.detalhe != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(s.detalhe!,
                      style:
                      TextStyle(color: colors.textFaint, fontSize: 12)),
                ),
              Icon(Icons.chevron_right, color: colors.textGhost, size: 18),
            ]),
          ),
        ),
    ];
  }
}