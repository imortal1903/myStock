import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/color_palette.dart';
import '../../../core/scanner/barcode_scanner_page.dart';
import '../../crud/models/lote.dart';
import '../../crud/models/produto.dart';
import '../../../core/extensions/quantidade_extensions.dart';
import '../models/item_carrinho.dart';
import '../viewmodels/venda_viewmodel.dart';
import '../models/produto_estoque.dart';
import 'venda_config_page.dart';

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

// Ordem de prioridade visual: Recomendado > Validade > Estoque.
const _ordemTags = [LoteTag.recomendado, LoteTag.validadeProxima, LoteTag.menorEstoque];

List<LoteTag> _ordenarTags(List<LoteTag> tags) {
  final resultado = [...tags]
    ..sort((a, b) => _ordemTags.indexOf(a).compareTo(_ordemTags.indexOf(b)));
  return resultado;
}

double _normalizar(num valor, num min, num max) =>
    max == min ? 0 : (valor - min) / (max - min);

/// Calcula as tags de cada lote de forma independente — um lote pode
/// acumular mais de uma tag, e nenhuma tag anula as outras.
///
/// [pesoValidade] (0.0 a 1.0) define o quanto o critério de validade pesa
/// no cálculo do lote "Recomendado"; o restante (1 - pesoValidade) é
/// aplicado ao critério de estoque. Ajustável em Vendas > Recomendação de lotes.
Map<int, List<LoteTag>> _calcularTags(List<Lote> lotes, [double pesoValidade = kPesoValidadePadrao]) {
  if (lotes.isEmpty) return {};

  // Validade mais próxima (empate: menor quantidade)
  var validadeProxima = lotes.first;
  for (final l in lotes) {
    final maisProximo = l.dataValidade.isBefore(validadeProxima.dataValidade);
    final empateMenorQtd = l.dataValidade.isAtSameMomentAs(validadeProxima.dataValidade) &&
        l.quantidade < validadeProxima.quantidade;
    if (maisProximo || empateMenorQtd) validadeProxima = l;
  }

  // Menor estoque (empate: validade mais próxima)
  var menorEstoque = lotes.first;
  for (final l in lotes) {
    final menosEstoque = l.quantidade < menorEstoque.quantidade;
    final empateMenorValidade = l.quantidade == menorEstoque.quantidade &&
        l.dataValidade.isBefore(menorEstoque.dataValidade);
    if (menosEstoque || empateMenorValidade) menorEstoque = l;
  }

  // Recomendado: melhor equilíbrio entre validade e estoque, conforme o
  // peso configurado pelo usuário. Pode coincidir com os lotes acima ou
  // ser um terceiro lote diferente.
  final pesoEstoque = 1 - pesoValidade;
  final dias = lotes.map((l) => l.diasParaVencer).toList();
  final qtds = lotes.map((l) => l.quantidade).toList();
  final diasMin = dias.reduce((a, b)  => a < b ? a : b);
  final diasMax = dias.reduce((a, b)  => a > b ? a : b);
  final qtdMin  = qtds.reduce((a, b)  => a < b ? a : b);
  final qtdMax  = qtds.reduce((a, b)  => a > b ? a : b);

  var recomendado = lotes.first;
  var melhorScore = double.infinity;
  for (final l in lotes) {
    final score = _normalizar(l.diasParaVencer, diasMin, diasMax) * pesoValidade +
        _normalizar(l.quantidade, qtdMin, qtdMax) * pesoEstoque;
    if (score < melhorScore) {
      melhorScore = score;
      recomendado = l;
    }
  }

  final tags = <int, List<LoteTag>>{};
  void adicionar(Lote l, LoteTag t) =>
      tags.putIfAbsent(l.id!, () => []).add(t);

  adicionar(validadeProxima, LoteTag.validadeProxima);
  adicionar(menorEstoque, LoteTag.menorEstoque);
  adicionar(recomendado, LoteTag.recomendado);

  return tags;
}

// ─── Página principal ───────────────────────────────────────────────────────

class VendasPage extends StatelessWidget {
  const VendasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            const _VendasTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 200),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 16),
                  const _VendaSearchSection(),
                  const SizedBox(height: 16),
                  const _VendaErrorBanner(),
                  Text('Produtos',
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  const _VendaProdutoList(),
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

class _VendasTopBar extends StatelessWidget {
  const _VendasTopBar();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendaViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(alignment: Alignment.center, children: [
        // Título centralizado na página inteira — independente de quantos
        // ícones existirem à direita (hoje são dois: config e carrinho).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 96),
          child: Text('Vendas',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              strutStyle: const StrutStyle(height: 1, forceStrutHeight: true),
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ),
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: context.colors.primary,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                Icons.point_of_sale_outlined, color: context.colors.onPrimary,
                size: 20),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _abrirConfiguracoes(context),
            icon: Icon(Icons.tune_rounded, color: context.colors.textPrimary),
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
                  child: Text(vm.quantidadeItens.formatada,
                      style: TextStyle(color: context.colors.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ]),
      ]),
    );
  }
}

void _abrirCarrinho(BuildContext context) {
  final vm = context.read<VendaViewModel>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        ChangeNotifierProvider.value(value: vm, child: const _CartSheet()),
  );
}

void _abrirSeletorDeLote(BuildContext context, ProdutoEstoque item) {
  final vm = context.read<VendaViewModel>();
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

void _abrirConfiguracoes(BuildContext context) {
  final vm = context.read<VendaViewModel>();
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const VendaConfigPage(),
      ),
    ),
  );
}

/// Controle de quantidade usado tanto no seletor de lote quanto no item do
/// carrinho: botões +/- e um campo de texto editável (aceita digitar o
/// valor exato, ex.: "1,5" para produtos vendidos por kg).
///
/// Importante: isto é *inline* na árvore de widgets, sem abrir diálogo/rota
/// nova. Uma versão anterior usava `showDialog`, mas — como este widget
/// vive dentro de um `showModalBottomSheet` com `DraggableScrollableSheet`
/// — abrir uma segunda rota (o diálogo) por cima gerava, em alguns casos,
/// o erro de framework "'_dependents.isEmpty': is not true" quando o
/// Provider notificava e reconstruía a lista ao mesmo tempo em que a rota
/// do diálogo estava sendo desmontada. Evitar abrir uma rota nova elimina
/// esse problema pela raiz.
class _QuantidadeControl extends StatefulWidget {
  final double quantidade;
  final double max;
  final bool fracionavel;
  final String unidade;
  final ValueChanged<double> onChanged;

  const _QuantidadeControl({
    required this.quantidade,
    required this.max,
    required this.fracionavel,
    required this.unidade,
    required this.onChanged,
  });

  @override
  State<_QuantidadeControl> createState() => _QuantidadeControlState();
}

class _QuantidadeControlState extends State<_QuantidadeControl> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.quantidade.formatada);
    _focusNode = FocusNode()..addListener(_aoMudarFoco);
  }

  @override
  void didUpdateWidget(covariant _QuantidadeControl old) {
    super.didUpdateWidget(old);
    // Só ressincroniza o texto quando o valor muda "por fora" (botões +/-,
    // ou o item foi removido/alterado por outra via) e o campo não está
    // em edição no momento — evita apagar o que o usuário está digitando.
    if (!_focusNode.hasFocus && old.quantidade != widget.quantidade) {
      _controller.text = widget.quantidade.formatada;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_aoMudarFoco);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  double get _passo => widget.fracionavel ? 0.1 : 1.0;

  void _alterar(double delta) {
    final nova = (widget.quantidade + delta).arredondada;
    if (nova < _passo || nova > widget.max) return;
    widget.onChanged(nova);
  }

  void _aoMudarFoco() {
    if (!_focusNode.hasFocus) _confirmarTexto();
  }

  void _confirmarTexto() {
    final valor = parseQuantidade(_controller.text);
    final invalido = valor == null ||
        valor <= 0 ||
        (!widget.fracionavel && !valor.isInteiro);
    if (invalido) {
      _controller.text = widget.quantidade.formatada; // reverte
      return;
    }
    final limitado = (valor > widget.max ? widget.max : valor).arredondada;
    _controller.text = limitado.formatada;
    if (limitado != widget.quantidade) widget.onChanged(limitado);
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _QtyButton(icon: Icons.remove, onTap: () => _alterar(-_passo)),
      SizedBox(
        width: widget.fracionavel ? 74 : 44,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: widget.fracionavel),
          onSubmitted: (_) => _focusNode.unfocus(),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      _QtyButton(icon: Icons.add, onTap: () => _alterar(_passo)),
    ]);
  }
}

// ─── Seletor de lote ───────────────────────────────────────────────────────

class _LoteSelectionSheet extends StatelessWidget {
  final ProdutoEstoque item;

  const _LoteSelectionSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendaViewModel>();
    final lotes = vm.lotesDisponiveis(item);
    final tags = _calcularTags(lotes, vm.pesoValidade);

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
              produto: item.produto,
              tags: tags[lotes[i].id] ?? const [],
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
  final Produto produto;
  final List<LoteTag> tags;
  final void Function(double quantidade) onAdicionar;

  const _LoteOptionTile({
    required this.lote,
    required this.produto,
    required this.onAdicionar,
    this.tags = const [],
  });

  @override
  State<_LoteOptionTile> createState() => _LoteOptionTileState();
}

class _LoteOptionTileState extends State<_LoteOptionTile> {
  late double _quantidade;

  @override
  void initState() {
    super.initState();
    final disponivel = widget.lote.quantidade;
    _quantidade = disponivel <= 0
        ? 0.0
        : (disponivel < 1 ? disponivel : 1.0);
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
    final lote = widget.lote;
    final tags = _ordenarTags(widget.tags);
    // A cor de destaque do card segue a tag de maior prioridade (Recomendado > Validade > Estoque).
    final corPrincipal = tags.isNotEmpty ? _corDaTag(context, tags.first) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: corPrincipal != null
            ? Border.all(color: corPrincipal.withValues(alpha: 0.5), width: 1.2)
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((t) {
              final cor = _corDaTag(context, t);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.icon, color: cor, size: 12),
                  const SizedBox(width: 4),
                  Text(t.label,
                      style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              );
            }).toList(),
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
              Text('Val: ${lote.validadeFormatada} · Qtd: ${lote.quantidade.formatada}',
                  style: TextStyle(color: context.colors.textFaint, fontSize: 12)),
            ]),
          ),
          Text(lote.precoVendaFormatado,
              style: TextStyle(color: context.colors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _QuantidadeControl(
            quantidade: _quantidade,
            max: widget.lote.quantidade,
            fracionavel: widget.produto.permiteFracao,
            unidade: widget.produto.unidade,
            onChanged: (v) => setState(() => _quantidade = v),
          ),
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

class _VendaSearchSection extends StatefulWidget {
  const _VendaSearchSection();

  @override
  State<_VendaSearchSection> createState() => _VendaSearchSectionState();
}

class _VendaSearchSectionState extends State<_VendaSearchSection> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendaViewModel>();

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
        _VendaCategoriaChips(vm: vm),
      ],
    ]);
  }

  Future<void> _buscarPorCodigoEAbrirLote(
      BuildContext context, VendaViewModel vm, String codigo) async {
    _ctrl.text = codigo;
    await vm.buscar(codigo);
    if (!context.mounted) return;

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

class _VendaCategoriaChips extends StatelessWidget {
  final VendaViewModel vm;
  const _VendaCategoriaChips({required this.vm});

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
            return _VendaCategoriaChip(
              label: 'Todas',
              selected: vm.categoriaFiltroId == null,
              onTap: () => vm.filtrarPorCategoria(null),
            );
          }
          final categoria = vm.categorias[i - 1];
          return _VendaCategoriaChip(
            label: categoria.nome,
            selected: vm.categoriaFiltroId == categoria.id,
            onTap: () => vm.filtrarPorCategoria(categoria.id),
          );
        },
      ),
    );
  }
}

class _VendaCategoriaChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _VendaCategoriaChip({required this.label, required this.selected, required this.onTap});

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

class _VendaErrorBanner extends StatelessWidget {
  const _VendaErrorBanner();

  @override
  Widget build(BuildContext context) {
    final erro = context
        .watch<VendaViewModel>()
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

class _VendaProdutoList extends StatelessWidget {
  const _VendaProdutoList();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendaViewModel>();

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
            .map((item) => _VendaProdutoCard(item: item))
            .toList());
  }
}

class _VendaProdutoCard extends StatelessWidget {
  final ProdutoEstoque item;

  const _VendaProdutoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final produto = item.produto;
    final disponivel = item.disponivelParaVenda;

    final Color badgeCor;
    final String badgeTexto;
    if (item.quantidadeDisponivel > 0) {
      badgeCor = context.colors.success;
      badgeTexto = 'Qtd: ${item.quantidadeDisponivel.formatada}';
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
    final vm = context.watch<VendaViewModel>();
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
            Text('${vm.quantidadeItens.formatada} ${vm.quantidadeItens == 1
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
    final vm = context.watch<VendaViewModel>();

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
    final vm = context.read<VendaViewModel>();
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
          _QuantidadeControl(
            quantidade: item.quantidade,
            max: item.lote.quantidade,
            fracionavel: item.produto.permiteFracao,
            unidade: item.produto.unidade,
            onChanged: (v) => vm.atualizarQuantidade(item, v),
          ),
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

/// Botão de +/- que dispara [onTap] uma vez em um toque normal, e repete
/// automaticamente enquanto o usuário mantém o botão pressionado — com uma
/// pequena espera inicial e depois acelerando, para permitir tanto ajustes
/// finos (toques únicos) quanto chegar rápido a quantidades maiores.
class _QtyButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  State<_QtyButton> createState() => _QtyButtonState();
}

class _QtyButtonState extends State<_QtyButton> {
  Timer? _timer;
  int _repeticoes = 0;

  void _iniciarRepeticao() {
    widget.onTap();
    _repeticoes = 0;
    _agendarProxima();
  }

  void _agendarProxima() {
    final atraso = _repeticoes == 0
        ? const Duration(milliseconds: 400) // espera antes de começar a repetir
        : Duration(milliseconds: (160 - _repeticoes * 12).clamp(40, 160));
    _timer = Timer(atraso, () {
      widget.onTap();
      _repeticoes++;
      _agendarProxima();
    });
  }

  void _pararRepeticao() {
    _timer?.cancel();
    _timer = null;
    _repeticoes = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: widget.onTap,
        onLongPressStart: (_) => _iniciarRepeticao(),
        onLongPressEnd: (_) => _pararRepeticao(),
        onLongPressCancel: _pararRepeticao,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: context.colors.bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(widget.icon, color: context.colors.textPrimary, size: 16),
        ),
      );
}

class _CartFooter extends StatelessWidget {
  final VendaViewModel vm;

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

  Future<void> _finalizar(BuildContext context, VendaViewModel vm) async {
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