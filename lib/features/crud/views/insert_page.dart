import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/produto.dart';
import '../viewmodels/insert_viewmodel.dart';
import '../../../core/theme/app_colors.dart';

class InsertPage extends StatelessWidget {
  const InsertPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InsertViewModel(),
      child: const _InsertView(),
    );
  }
}

class _InsertView extends StatefulWidget {
  const _InsertView();
  @override State<_InsertView> createState() => _InsertViewState();
}

class _InsertViewState extends State<_InsertView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _nomeCtrl        = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _barcodeCtrl     = TextEditingController();
  final _estoqueMinCtrl  = TextEditingController(); // ADICIONADO
  final _loteNumCtrl     = TextEditingController();
  final _qtdCtrl         = TextEditingController();
  final _precoCtrl       = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _barcodeCtrl.dispose();
    _estoqueMinCtrl.dispose(); // ADICIONADO
    _loteNumCtrl.dispose();
    _qtdCtrl.dispose();
    _precoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext ctx,
      {required bool isValidade}) async {
    final vm = ctx.read<InsertViewModel>();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: isValidade
          ? DateTime.now().add(const Duration(days: 30))
          : DateTime.now(),
      firstDate: isValidade
          ? DateTime.now()
          : DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (c, child) => _dateTheme(c, child!),
    );
    if (picked != null) {
      isValidade
          ? vm.setDataValidade(picked)
          : vm.setDataFabricacao(picked);
    }
  }

  Widget _dateTheme(BuildContext c, Widget child) => Theme(
    data: Theme.of(c).copyWith(
      colorScheme: const ColorScheme.dark(
          primary: AppColors.accent, surface: AppColors.surface),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InsertViewModel>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Novo Produto',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.white38,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Produto'),
            Tab(icon: Icon(Icons.layers_outlined),       text: 'Lote'),
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
            estoqueMinCtrl: _estoqueMinCtrl, // ADICIONADO
          ),
          _LoteTab(
            vm: vm, loteNumCtrl: _loteNumCtrl,
            qtdCtrl: _qtdCtrl, precoCtrl: _precoCtrl,
            onPickValidade: () => _pickDate(context, isValidade: true),
            onPickFabricacao: () => _pickDate(context, isValidade: false),
          ),
        ],
      ),
      bottomNavigationBar: _SaveBar(
        isLoading: vm.isLoading,
        errorMessage: vm.errorMessage,
        temDadosLote: vm.temDadosLote,
        onSave: () async {
          final ok = await context.read<InsertViewModel>().save();
          if (ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                vm.temDadosLote
                    ? 'Produto e lote salvos!'
                    : 'Produto salvo!',
              ),
              backgroundColor: AppColors.primary,
            ));
            context.read<InsertViewModel>().reset();
            _nomeCtrl.clear();
            _descCtrl.clear();
            _barcodeCtrl.clear();
            _estoqueMinCtrl.clear(); // ADICIONADO
            _loteNumCtrl.clear();
            _qtdCtrl.clear();
            _precoCtrl.clear();
            _tabs.animateTo(0);
          }
        },
      ),
    );
  }
}

// ── Aba Produto ───────────────────────────────────────────────────────────────

class _ProdutoTab extends StatefulWidget {
  final InsertViewModel vm;
  final TextEditingController nomeCtrl, descCtrl, barcodeCtrl, estoqueMinCtrl; // ADICIONADO

  const _ProdutoTab({
    required this.vm,
    required this.nomeCtrl,
    required this.descCtrl,
    required this.barcodeCtrl,
    required this.estoqueMinCtrl, // ADICIONADO
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
              _Field(label: 'Nome *', hint: 'Ex: Arroz Branco', ctrl: widget.nomeCtrl,
                  icon: Icons.shopping_bag_outlined,
                  onSaved: (v) => vm.nome = v ?? '',
                  validator: vm.validateNome,
                  capitalization: TextCapitalization.words),
              const SizedBox(height: 14),
              _Field(label: 'Descrição', hint: 'Detalhes do produto', ctrl: widget.descCtrl,
                  icon: Icons.description_outlined, maxLines: 3,
                  onSaved: (v) => vm.descricao = v ?? ''),
              const SizedBox(height: 14),
              _Field(label: 'Código de barras', hint: 'EAN / GTIN', ctrl: widget.barcodeCtrl,
                  icon: Icons.qr_code_outlined,
                  keyboardType: TextInputType.number,
                  onSaved: (v) => vm.codigoBarras = v ?? ''),
              const SizedBox(height: 14),

              // NOVO CAMPO: Estoque Mínimo
              _Field(label: 'Estoque mínimo', hint: 'Ex: 10', ctrl: widget.estoqueMinCtrl,
                  icon: Icons.warning_amber_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: vm.validateEstoqueMin,
                  onSaved: (v) => vm.estoqueMinText = v ?? ''),
              const SizedBox(height: 14),

              // Unidade
              const _Label('Unidade de medida'),
              const SizedBox(height: 8),
              _Dropdown(
                value: vm.unidade,
                items: Produto.unidades,
                onChanged: vm.setUnidade,
              ),
              const SizedBox(height: 14),
              // Categoria
              if (vm.categorias.isNotEmpty) ...[
                const _Label('Categoria'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: vm.categoriaId,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.accent),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Sem categoria', style: TextStyle(color: Colors.white54))),
                        ...vm.categorias.map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.nome))),
                      ],
                      onChanged: vm.setCategoria,
                    ),
                  ),
                ),
              ],
            ]),
      ),
    );
  }
}

// ── Aba Lote ──────────────────────────────────────────────────────────────────

class _LoteTab extends StatefulWidget {
  final InsertViewModel vm;
  final TextEditingController loteNumCtrl, qtdCtrl, precoCtrl;
  final VoidCallback onPickValidade, onPickFabricacao;

  const _LoteTab({
    required this.vm,
    required this.loteNumCtrl,
    required this.qtdCtrl,
    required this.precoCtrl,
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
              _Field(label: 'Nº do Lote', hint: 'Ex: LOT-2024-001', ctrl: widget.loteNumCtrl,
                  icon: Icons.tag_outlined,
                  onSaved: (v) => vm.numeroLote = v ?? ''),
              const SizedBox(height: 14),
              _Field(label: 'Quantidade *', hint: '0', ctrl: widget.qtdCtrl,
                  icon: Icons.numbers_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSaved: (v) => vm.quantidadeText = v ?? '',
                  validator: vm.validateQuantidade),
              const SizedBox(height: 14),
              _Field(label: 'Preço de custo (R\u0024)', hint: '0,00', ctrl: widget.precoCtrl,
                  icon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                  onSaved: (v) => vm.precoCustoText = v ?? '',
                  validator: vm.validatePrecoCusto),
              const SizedBox(height: 14),
              const _Label('Data de validade *'),
              const SizedBox(height: 8),
              _DateButton(
                date: vm.dataValidade,
                hint: 'Selecionar data de validade',
                onTap: widget.onPickValidade,
              ),
              const SizedBox(height: 14),
              const _Label('Data de fabricação'),
              const SizedBox(height: 8),
              _DateButton(
                date: vm.dataFabricacao,
                hint: 'Selecionar data de fabricação',
                onTap: widget.onPickFabricacao,
              ),
              const SizedBox(height: 14),
              const _Label('Data de entrada'),
              const SizedBox(height: 8),
              _DateButton(
                date: vm.dataEntrada,
                hint: 'Hoje',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: vm.dataEntrada,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (c, child) => Theme(
                      data: Theme.of(c).copyWith(
                        colorScheme: const ColorScheme.dark(
                            primary: AppColors.accent, surface: AppColors.surface),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) vm.setDataEntrada(picked);
                },
              ),
            ]),
      ),
    );
  }
}

// ── Save bar ──────────────────────────────────────────────────────────────────
class _SaveBar extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSave;
  final bool temDadosLote;

  const _SaveBar({
    required this.isLoading,
    this.errorMessage,
    required this.onSave,
    required this.temDadosLote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(temDadosLote
                ? 'Salvar produto e lote'
                : 'Salvar produto',
                style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500));
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;

  const _Field({
    required this.label, required this.hint,
    required this.ctrl, required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onSaved, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label(label),
      const SizedBox(height: 8),
      TextFormField(
        controller: ctrl, maxLines: maxLines,
        keyboardType: keyboardType, textCapitalization: capitalization,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Colors.white30),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          filled: true, fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
          errorStyle: const TextStyle(color: Colors.redAccent),
        ),
        onSaved: onSaved, validator: validator,
      ),
    ]);
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _Dropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, isExpanded: true,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.accent),
        items: items.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
        onChanged: (v) => onChanged(v!),
      ),
    ),
  );
}

class _DateButton extends StatelessWidget {
  final DateTime? date;
  final String hint;
  final VoidCallback onTap;
  const _DateButton({required this.date, required this.hint, required this.onTap});

  String get _label => date == null ? hint
      : '${date!.day.toString().padLeft(2,'0')}/${date!.month.toString().padLeft(2,'0')}/${date!.year}';

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: date != null ? AppColors.accent : Colors.transparent, width: 1.5),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today, color: Colors.white38, size: 20),
        const SizedBox(width: 12),
        Text(_label, style: TextStyle(color: date == null ? Colors.white38 : Colors.white, fontSize: 15)),
        const Spacer(),
        const Icon(Icons.keyboard_arrow_down, color: AppColors.accent, size: 20),
      ]),
    ),
  );
}