import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/produto.dart';
import '../viewmodels/insert_viewmodel.dart';
import 'widgets/form_widgets.dart';
import '../../../core/theme/color_palette.dart';

class InsertPage extends StatelessWidget {
  const InsertPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => InsertViewModel(),
    child: const _InsertView(),
  );
}

class _InsertView extends StatefulWidget {
  const _InsertView();
  @override
  State<_InsertView> createState() => _InsertViewState();
}

class _InsertViewState extends State<_InsertView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  final _nomeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _estoqueMinCtrl = TextEditingController();
  final _loteNumCtrl = TextEditingController();
  final _qtdCtrl = TextEditingController();
  final _precoCustoCtrl = TextEditingController();
  final _precoVendaCtrl = TextEditingController();

  late final List<TextEditingController> _allCtrls = [
    _nomeCtrl,
    _descCtrl,
    _barcodeCtrl,
    _estoqueMinCtrl,
    _loteNumCtrl,
    _qtdCtrl,
    _precoCustoCtrl,
    _precoVendaCtrl,
  ];

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _allCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isValidade}) async {
    final vm = context.read<InsertViewModel>();
    final picked = await showDatePicker(
      context: context,
      initialDate: isValidade
          ? DateTime.now().add(const Duration(days: 30))
          : DateTime.now(),
      firstDate: isValidade ? DateTime.now() : DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (c, child) => buildThemedDatePicker(c, child!),
    );
    if (picked == null) return;
    isValidade ? vm.setDataValidade(picked) : vm.setDataFabricacao(picked);
  }

  Future<void> _onSave() async {
    final vm = context.read<InsertViewModel>();
    final tinhaLote = vm.temDadosLote;
    final ok = await vm.save();
    if (!ok || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tinhaLote ? 'Produto e lote salvos!' : 'Produto salvo!'),
      backgroundColor: context.colors.primary,
    ));

    vm.reset();
    for (final c in _allCtrls) {
      c.clear();
    }
    _tabs.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InsertViewModel>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: colors.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Novo Produto',
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: colors.accent,
          unselectedLabelColor: colors.textFaint,
          indicatorColor: colors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Produto'),
            Tab(icon: Icon(Icons.layers_outlined), text: 'Lote'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProdutoTab(
            vm: vm,
            nomeCtrl: _nomeCtrl,
            descCtrl: _descCtrl,
            barcodeCtrl: _barcodeCtrl,
            estoqueMinCtrl: _estoqueMinCtrl,
          ),
          _LoteTab(
            vm: vm,
            loteNumCtrl: _loteNumCtrl,
            qtdCtrl: _qtdCtrl,
            precoCustoCtrl: _precoCustoCtrl,
            precoVendaCtrl: _precoVendaCtrl,
            onPickValidade: () => _pickDate(isValidade: true),
            onPickFabricacao: () => _pickDate(isValidade: false),
          ),
        ],
      ),
      bottomNavigationBar: _SaveBar(
        isLoading: vm.isLoading,
        errorMessage: vm.errorMessage,
        temDadosLote: vm.temDadosLote,
        onSave: _onSave,
      ),
    );
  }
}

// ── Aba Produto ──
class _ProdutoTab extends StatefulWidget {
  final InsertViewModel vm;
  final TextEditingController nomeCtrl, descCtrl, barcodeCtrl, estoqueMinCtrl;

  const _ProdutoTab({
    required this.vm,
    required this.nomeCtrl,
    required this.descCtrl,
    required this.barcodeCtrl,
    required this.estoqueMinCtrl,
  });

  @override
  State<_ProdutoTab> createState() => _ProdutoTabState();
}

class _ProdutoTabState extends State<_ProdutoTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final vm = widget.vm;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: vm.produtoFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormField_(
              label: 'Nome *',
              hint: 'Ex: Arroz Branco',
              ctrl: widget.nomeCtrl,
              icon: Icons.shopping_bag_outlined,
              capitalization: TextCapitalization.words,
              validator: vm.validateNome,
              onSaved: (v) => vm.nome = v ?? '',
            ),
            const SizedBox(height: 14),
            FormField_(
              label: 'Descrição',
              hint: 'Detalhes do produto',
              ctrl: widget.descCtrl,
              icon: Icons.description_outlined,
              maxLines: 3,
              onSaved: (v) => vm.descricao = v ?? '',
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FormField_(
                    label: 'Código de barras',
                    hint: 'EAN / GTIN',
                    ctrl: widget.barcodeCtrl,
                    icon: Icons.qr_code_outlined,
                    keyboardType: TextInputType.number,
                    validator: vm.validateCodigoBarras,
                    onChanged: vm.setCodigoBarras,
                    onSaved: (v) => vm.codigoBarras = v ?? '',
                  ),
                ),
                const SizedBox(width: 10),
                ScanButton(
                  onScanned: (codigo) {
                    widget.barcodeCtrl.text = codigo;
                    vm.setCodigoBarras(codigo);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            FormField_(
              label: 'Estoque mínimo',
              hint: 'Ex: 10',
              ctrl: widget.estoqueMinCtrl,
              icon: Icons.warning_amber_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: FormFormatters.digits,
              validator: vm.validateEstoqueMin,
              onSaved: (v) => vm.estoqueMinText = v ?? '',
            ),
            const SizedBox(height: 14),
            const FormLabel('Unidade de medida'),
            const SizedBox(height: 8),
            FormDropdown.strings(
              value: vm.unidade,
              items: Produto.unidades,
              onChanged: vm.setUnidade,
            ),
            const SizedBox(height: 14),
            const FormLabel('Categoria'),
            const SizedBox(height: 8),
            if (vm.categorias.isEmpty)
              const CategoriaEmptyWarning()
            else
              FormDropdown<int?>(
                value: vm.categoriaId,
                onChanged: vm.setCategoria,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Sem categoria',
                        style: TextStyle(color: context.colors.textMuted)),
                  ),
                  ...vm.categorias.map(
                        (c) => DropdownMenuItem(value: c.id, child: Text(c.nome)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Aba Lote ──
class _LoteTab extends StatefulWidget {
  final InsertViewModel vm;
  final TextEditingController loteNumCtrl,
      qtdCtrl,
      precoCustoCtrl,
      precoVendaCtrl;
  final VoidCallback onPickValidade, onPickFabricacao;

  const _LoteTab({
    required this.vm,
    required this.loteNumCtrl,
    required this.qtdCtrl,
    required this.precoCustoCtrl,
    required this.precoVendaCtrl,
    required this.onPickValidade,
    required this.onPickFabricacao,
  });

  @override
  State<_LoteTab> createState() => _LoteTabState();
}

class _LoteTabState extends State<_LoteTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final vm = widget.vm;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: vm.loteFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormField_(
              label: 'Nº do Lote',
              hint: 'Ex: LOT-2024-001',
              ctrl: widget.loteNumCtrl,
              icon: Icons.tag_outlined,
              onChanged: vm.setNumeroLote,
              onSaved: (v) => vm.numeroLote = v ?? '',
            ),
            const SizedBox(height: 14),
            FormField_(
              label: 'Quantidade *',
              hint: '0',
              ctrl: widget.qtdCtrl,
              icon: Icons.numbers_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: FormFormatters.digits,
              validator: vm.validateQuantidade,
              onChanged: vm.setQuantidade,
              onSaved: (v) => vm.quantidadeText = v ?? '',
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormField_(
                    label: 'Preço de custo (R\u0024) *',
                    hint: '0,00',
                    ctrl: widget.precoCustoCtrl,
                    icon: Icons.attach_money,
                    keyboardType: FormFormatters.decimalKeyboard,
                    inputFormatters: FormFormatters.decimal,
                    validator: vm.validatePrecoCusto,
                    onChanged: vm.setPrecoCusto,
                    onSaved: (v) => vm.precoCustoText = v ?? '',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FormField_(
                    label: 'Preço de venda (R\u0024) *',
                    hint: '0,00',
                    ctrl: widget.precoVendaCtrl,
                    icon: Icons.sell_outlined,
                    keyboardType: FormFormatters.decimalKeyboard,
                    inputFormatters: FormFormatters.decimal,
                    validator: vm.validatePrecoVenda,
                    onChanged: vm.setPrecoVenda,
                    onSaved: (v) => vm.precoVendaText = v ?? '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FormLabel('Data de validade *'),
            const SizedBox(height: 8),
            DateButton(
              date: vm.dataValidade,
              hint: 'Selecionar data de validade',
              onTap: widget.onPickValidade,
            ),
            const SizedBox(height: 14),
            const FormLabel('Data de fabricação'),
            const SizedBox(height: 8),
            DateButton(
              date: vm.dataFabricacao,
              hint: 'Selecionar data de fabricação',
              onTap: widget.onPickFabricacao,
            ),
            const SizedBox(height: 14),
            const FormLabel('Data de entrada'),
            const SizedBox(height: 8),
            DateButton(
              date: vm.dataEntrada,
              hint: 'Hoje',
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: vm.dataEntrada,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  builder: (c, child) => buildThemedDatePicker(c, child!),
                );
                if (picked != null) vm.setDataEntrada(picked);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Save bar ──
class _SaveBar extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSave;
  final bool temDadosLote;

  const _SaveBar({
    required this.isLoading,
    required this.onSave,
    required this.temDadosLote,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.bg,
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(errorMessage!,
                style:
                const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.accent,
              disabledBackgroundColor:
              context.colors.accent.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: isLoading
                ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: context.colors.textPrimary, strokeWidth: 2.5),
            )
                : Text(
              temDadosLote ? 'Salvar produto e lote' : 'Salvar produto',
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}