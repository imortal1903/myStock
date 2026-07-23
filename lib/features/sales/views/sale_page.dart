import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/color_palette.dart';
import '../../../core/scanner/barcode_scanner_page.dart';
import '../../crud/models/lote.dart';
import '../models/item_carrinho.dart';
import '../viewmodels/sale_viewmodel.dart';
import '../models/produto_estoque.dart';

String _formatarMoeda(double v) =>
    'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

// ─── Tags de recomendação de lote ─────────────────────────────────────────

enum LoteTag { recomendado, validadeProxima, menorEstoque }

extension LoteTagX on LoteTag {
  String get label {
    switch (this) {
      case LoteTag.recomendado: return 'Recomendado';
      case LoteTag.validadeProxima: return 'Validade mais próxima';
      case LoteTag.menorEstoque: return 'Menor estoque';
    }
  }

  IconData get icon {
    switch (this) {
      case LoteTag.recomendado: return Icons.star_rounded;
      case LoteTag.validadeProxima: return Icons.schedule_rounded;
      case LoteTag.menorEstoque: return Icons.inventory_2_outlined;
    }
  }
}

Map<int, LoteTag> _calcularTags(List<Lote> lotes) {
  if (lotes.isEmpty) return {};

  var validadeProxima = lotes.first;
  for (final l in lotes) {
    final maisProximo = l.dataValidade.isBefore(validadeProxima.dataValidade);
    final empateMenorQtd = l.dataValidade.isAtSameMomentAs(validadeProxima.dataValidade) &&
        l.quantidade < validadeProxima.quantidade;
    if (maisProximo || empateMenorQtd) validadeProxima = l;
  }

  var menorEstoque = lotes.first;
  for (final l in lotes) {
    if (l.quantidade < menorEstoque.quantidade) menorEstoque = l;
  }

  final tags = <int, LoteTag>{};
  if (validadeProxima.id == menorEstoque.id) {
    tags[validadeProxima.id!] = LoteTag.recomendado;
  } else {
    tags[validadeProxima.id!] = LoteTag.validadeProxima;
    tags[menorEstoque.id!] = LoteTag.menorEstoque;
  }
  return tags;
}

// ─── Página principal ───────────────────────────────────────────────────────

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            const _SalesTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 200),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 16),
                  const _SaleSearchSection(),
                  const SizedBox(height: 16),
                  const _SaleErrorBanner(),
                  Text('Produtos',
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  const _SaleProductList(),
                ]),
              ),
            ),
          ]),
          const Positioned(
              left: 0, right: 0, bottom: 16, child: _CartSummaryBar()),
        ]),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _SalesTopBar extends StatelessWidget {
  const _SalesTopBar();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: context.colors.primary,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(
              Icons.point_of_sale_outlined, color: context.colors.onPrimary,
              size: 20),
        ),
        Expanded(
          child: Center(
            child: Text('Vendas',
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
        ),
        Stack(clipBehavior: Clip.none, children: [
          IconButton(
            onPressed: () => _abrirCarrinho(context),
            icon: Icon(Icons.shopping_cart_outlined,
                color: context.colors.textPrimary),
          ),
          if (vm.quantidadeItens > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: context.colors.danger,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${vm.quantidadeItens}',
                    style: TextStyle(color: context.colors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ]),
    );
  }
}

void _abrirCarrinho(BuildContext context) {
  final vm = context.read<SaleViewModel>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        ChangeNotifierProvider.value(value: vm, child: const _CartSheet()),
  );
}

void _abrirSeletorDeLote(BuildContext context, ProdutoEstoque item) {
  final vm = context.read<SaleViewModel>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        ChangeNotifierProvider.value(
          value: vm,
          child: _LoteSelectionSheet(item: item),
        ),
  );
}

// ─── Seletor de lote ───────────────────────────────────────────────────────

class _LoteSelectionSheet extends StatelessWidget {
  final ProdutoEstoque item;

  const _LoteSelectionSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleViewModel>();
    final lotes = vm.lotesDisponiveis(item);
    final tags = _calcularTags(lotes);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(
        color: context.colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: context.colors.divider, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Escolher lote',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(item.produto.nome,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textFaint, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: lotes.isEmpty
              ? Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Nenhum lote disponível.',
                style: TextStyle(color: context.colors.textFaint, fontSize: 14)),
          )
              : ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: lotes.length,
            itemBuilder: (_, i) => _LoteOptionTile(
              lote: lotes[i],
              tag: tags[lotes[i].id],
              onAdicionar: (qtd) {
                vm.adicionarAoCarrinho(item, lotes[i], quantidade: qtd);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _LoteOptionTile extends StatefulWidget {
  final Lote lote;
  final LoteTag? tag;
  final void Function(int quantidade) onAdicionar;

  const _LoteOptionTile({required this.lote, required this.onAdicionar, this.tag});

  @override
  State<_LoteOptionTile> createState() => _LoteOptionTileState();
}

class _LoteOptionTileState extends State<_LoteOptionTile> {
  late int _quantidade;

  @override
  void initState() {
    super.initState();
    _quantidade = widget.lote.quantidade > 0 ? 1 : 0;
  }

  void _alterar(int delta) {
    final nova = _quantidade + delta;
    if (nova < 1 || nova > widget.lote.quantidade) return;
    setState(() => _quantidade = nova);
  }

  Color _corDaTag(BuildContext context, LoteTag t) {
    switch (t) {
      case LoteTag.recomendado: return context.colors.success;
      case LoteTag.validadeProxima: return Colors.orangeAccent;
      case LoteTag.menorEstoque: return context.colors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;
    final lote = widget.lote;
    final cor = tag != null ? _corDaTag(context, tag) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: cor != null ? Border.all(color: cor.withValues(alpha: 0.5), width: 1.2) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (tag != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cor!.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(tag.icon, color: cor, size: 12),
              const SizedBox(width: 4),
              Text(tag.label,
                  style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.layers_outlined, color: context.colors.onPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                lote.numeroLote?.isNotEmpty == true ? lote.numeroLote! : 'Lote #${lote.id}',
                style: TextStyle(color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text('Val: ${lote.validadeFormatada} · Qtd: ${lote.quantidade}',
                  style: TextStyle(color: context.colors.textFaint, fontSize: 12)),
            ]),
          ),
          Text(lote.precoCustoFormatado,
              style: TextStyle(color: context.colors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _QtyButton(icon: Icons.remove, onTap: () => _alterar(-1)),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text('$_quantidade',
                style: TextStyle(color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          _QtyButton(icon: Icons.add, onTap: () => _alterar(1)),
          const Spacer(),
          ElevatedButton(
            onPressed: _quantidade > 0 ? () => widget.onAdicionar(_quantidade) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Adicionar',
                style: TextStyle(color: context.colors.onPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}

// ─── Busca + filtro por categoria ──────────────────────────────────────────────

class _SaleSearchSection extends StatefulWidget {
  const _SaleSearchSection();

  @override
  State<_SaleSearchSection> createState() => _SaleSearchSectionState();
}

class _SaleSearchSectionState extends State<_SaleSearchSection> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleViewModel>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _ctrl,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
                onChanged: vm.buscar,
                decoration: InputDecoration(
                  hintText: 'Buscar produto para vender...',
                  hintStyle: TextStyle(color: context.colors.textFaint, fontSize: 14),
                  prefixIcon: Icon(
                      Icons.search, color: context.colors.textFaint, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ScanButton(onScanned: (codigo) => _buscarPorCodigoEAbrirLote(context, vm, codigo)),
        ],
      ),
      if (vm.categorias.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SaleCategoryChips(vm: vm),
      ],
    ]);
  }

  Future<void> _buscarPorCodigoEAbrirLote(
      BuildContext context, SaleViewModel vm, String codigo) async {
    _ctrl.text = codigo;
    await vm.buscar(codigo);
    if (!mounted) return;

    ProdutoEstoque? encontrado;
    for (final r in vm.resultados) {
      if (r.produto.codigoBarras == codigo) {
        encontrado = r;
        break;
      }
    }

    if (encontrado != null) {
      _abrirSeletorDeLote(context, encontrado);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nenhum produto encontrado com esse código de barras.'),
          backgroundColor: context.colors.danger,
        ),
      );
    }
  }
}

class _ScanButton extends StatelessWidget {
  final Future<void> Function(String codigo) onScanned;
  const _ScanButton({required this.onScanned});

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final codigo = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
        );
        if (codigo != null && codigo.isNotEmpty) {
          await onScanned(codigo);
        }
      },
      child: Container(
        width: 46, height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.accent, width: 1.5),
        ),
        child: Icon(Icons.qr_code_scanner, color: context.colors.accent, size: 22),
      ),
    ),
  );
}

class _SaleCategoryChips extends StatelessWidget {
  final SaleViewModel vm;
  const _SaleCategoryChips({required this.vm});

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
            return _SaleCategoryChip(
              label: 'Todas',
              selected: vm.categoriaFiltroId == null,
              onTap: () => vm.filtrarPorCategoria(null),
            );
          }
          final categoria = vm.categorias[i - 1];
          return _SaleCategoryChip(
            label: categoria.nome,
            selected: vm.categoriaFiltroId == categoria.id,
            onTap: () => vm.filtrarPorCategoria(categoria.id),
          );
        },
      ),
    );
  }
}

class _SaleCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SaleCategoryChip({required this.label, required this.selected, required this.onTap});

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

// ─── Banner de erro ─────────────────────────────────────────────────────────

class _SaleErrorBanner extends StatelessWidget {
  const _SaleErrorBanner();

  @override
  Widget build(BuildContext context) {
    final erro = context
        .watch<SaleViewModel>()
        .erroCarrinho;
    if (erro == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: context.colors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: context.colors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(erro,
              style: TextStyle(color: context.colors.danger, fontSize: 12))),
        ]),
      ),
    );
  }
}

// ─── Lista de produtos ────────────────────────────────────────────────────────

class _SaleProductList extends StatelessWidget {
  const _SaleProductList();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleViewModel>();

    if (vm.buscando) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(color: context.colors.accent),
        ),
      );
    }
    if (vm.erroBusca != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(vm.erroBusca!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
        ),
      );
    }
    if (vm.resultados.isEmpty) {
      final categoria = vm.categoriaFiltroSelecionada;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined, color: context.colors.divider,
                size: 52),
            const SizedBox(height: 12),
            Text(
              categoria != null
                  ? 'Nenhum produto em "${categoria.nome}".'
                  : 'Nenhum produto encontrado.',
              style: TextStyle(color: context.colors.textFaint, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }

    return Column(
        children: vm.resultados
            .map((item) => _SaleProductCard(item: item))
            .toList());
  }
}

class _SaleProductCard extends StatelessWidget {
  final ProdutoEstoque item;

  const _SaleProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final produto = item.produto;
    final disponivel = item.disponivelParaVenda;

    final Color badgeCor;
    final String badgeTexto;
    if (item.quantidadeDisponivel > 0) {
      badgeCor = context.colors.success;
      badgeTexto = 'Qtd: ${item.quantidadeDisponivel}';
    } else if (item.vencido) {
      badgeCor = context.colors.danger;
      badgeTexto = 'Vencido';
    } else {
      badgeCor = Colors.orangeAccent;
      badgeTexto = 'Esgotado';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.colors.primary,
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.colors.primaryDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.accent, width: 1.5),
          ),
          child: Icon(
              Icons.inventory_2_outlined, color: context.colors.onPrimary,
              size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(produto.nome,
                    style: TextStyle(color: context.colors.onPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeCor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badgeTexto,
                    style: TextStyle(color: badgeCor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(produto.unidade, style: TextStyle(
                color: context.colors.onPrimaryMuted, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: disponivel ? () => _abrirSeletorDeLote(context, item) : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: disponivel ? context.colors.accent : context.colors
                  .textGhost,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.add,
                color: disponivel ? context.colors.primaryDark : context.colors
                    .textFaint, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ─── Barra flutuante do carrinho ──────────────────────────────────────────────

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleViewModel>();
    if (vm.carrinho.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _abrirCarrinho(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(children: [
            Icon(
                Icons.shopping_cart, color: context.colors.onPrimary, size: 20),
            const SizedBox(width: 10),
            Text('${vm.quantidadeItens} ${vm.quantidadeItens == 1
                ? 'item'
                : 'itens'}',
                style: TextStyle(color: context.colors.onPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_formatarMoeda(vm.totalCarrinho),
                style: TextStyle(color: context.colors.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: context.colors.onPrimarySecondary,
                size: 20),
          ]),
        ),
      ),
    );
  }
}

// ─── Bottom sheet do carrinho ─────────────────────────────────────────────────

class _CartSheet extends StatelessWidget {
  const _CartSheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleViewModel>();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) =>
          Container(
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: context.colors.divider,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Carrinho',
                          style: TextStyle(color: context.colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      if (vm.carrinho.isNotEmpty)
                        GestureDetector(
                          onTap: vm.limparCarrinho,
                          child: Text('Limpar',
                              style: TextStyle(color: context.colors.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                    ]),
              ),
              if (vm.erroCarrinho != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Text(vm.erroCarrinho!, style: TextStyle(
                      color: context.colors.danger, fontSize: 12)),
                ),
              Expanded(
                child: vm.carrinho.isEmpty
                    ? Center(
                    child: Text('Seu carrinho está vazio.',
                        style: TextStyle(
                            color: context.colors.textFaint, fontSize: 14)))
                    : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: vm.carrinho.length,
                  itemBuilder: (_, i) => _CartItemTile(item: vm.carrinho[i]),
                ),
              ),
              _CartFooter(vm: vm),
            ]),
          ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final ItemCarrinho item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<SaleViewModel>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.colors.surface,
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(item.produto.nome,
                style: TextStyle(color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () => vm.removerDoCarrinho(item),
            child: Icon(Icons.close, color: context.colors.textFaint, size: 18),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _QtyButton(icon: Icons.remove,
              onTap: () => vm.atualizarQuantidade(item, item.quantidade - 1)),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text('${item.quantidade}',
                style: TextStyle(color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          _QtyButton(icon: Icons.add,
              onTap: () => vm.atualizarQuantidade(item, item.quantidade + 1)),
          const Spacer(),
          Text(item.subtotalFormatado,
              style: TextStyle(color: context.colors.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: context.colors.bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: context.colors.textPrimary, size: 16),
        ),
      );
}

class _CartFooter extends StatelessWidget {
  final SaleViewModel vm;

  const _CartFooter({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery
          .of(context)
          .padding
          .bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total', style: TextStyle(
              color: context.colors.textSecondary, fontSize: 14)),
          Text(_formatarMoeda(vm.totalCarrinho),
              style: TextStyle(color: context.colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: vm.carrinho.isEmpty || vm.finalizando ? null : () =>
                _finalizar(context, vm),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: vm.finalizando
                ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: context.colors.onPrimary))
                : Text('Finalizar Venda',
                style: TextStyle(color: context.colors.onPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Future<void> _finalizar(BuildContext context, SaleViewModel vm) async {
    final vendaId = await vm.finalizarVenda();
    if (!context.mounted) return;
    if (vendaId != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Venda #$vendaId concluída com sucesso!'),
          backgroundColor: context.colors.success,
        ),
      );
    }
  }
}