import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/lote.dart';
import '../models/produto.dart';
import '../viewmodels/update_viewmodel.dart';
import '../../../core/theme/app_colors.dart';

class UpdatePage extends StatelessWidget {
  const UpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UpdateViewModel(),
      child: const _UpdateView(),
    );
  }
}

class _UpdateView extends StatelessWidget {
  const _UpdateView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UpdateViewModel>();

    if (vm.status == UpdateStatus.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Salvo com sucesso!'),
          backgroundColor: context.colors.primary,
        ));
        context.read<UpdateViewModel>().resetStatus();
      });
    }

    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: context.colors.textSecondary, size: 18),
          onPressed: () {
            final vm = context.read<UpdateViewModel>();
            if (vm.selectedLote != null) {
              vm.clearLoteSelection();
            } else if (vm.selectedProduto != null) {
              vm.clearProdutoSelection();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _title(context.watch<UpdateViewModel>()),
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _body(context, vm),
    );
  }

  // CORREÇÃO: Tratamento visual para lote novo ou em edição
  String _title(UpdateViewModel vm) {
    if (vm.selectedLote != null) {
      return vm.selectedLote!.id == null ? 'Novo Lote' : 'Editar Lote';
    }
    if (vm.selectedProduto != null) return 'Produto: ${vm.selectedProduto!.nome}';
    return 'Selecionar Produto';
  }

  Widget _body(BuildContext context, UpdateViewModel vm) {
    if (vm.selectedLote != null)    return _LoteForm(vm: vm);
    if (vm.selectedProduto != null) return _ProdutoDetail(vm: vm);
    return _ProductList(vm: vm);
  }
}

// ── Etapa 1: Lista de produtos ────────────────────────────────────────────────

class _ProductList extends StatelessWidget {
  final UpdateViewModel vm;
  const _ProductList({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading && vm.produtos.isEmpty) {
      return Center(child: CircularProgressIndicator(color: context.colors.accent));
    }
    if (vm.produtos.isEmpty) {
      return Center(child: Text('Nenhum produto cadastrado.',
          style: TextStyle(color: context.colors.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vm.produtos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _ProductTile(
        produto: vm.produtos[i],
        onTap: () => vm.selectProduto(vm.produtos[i]),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Produto produto;
  final VoidCallback onTap;
  const _ProductTile({required this.produto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.divider)),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: context.colors.primary, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.inventory_2_outlined, color: context.colors.onPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(produto.nome, style: TextStyle(
                color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${produto.unidade} · ${produto.ativo ? "Ativo" : "Inativo"}',
                style: TextStyle(color: context.colors.accent, fontSize: 12)),
          ])),
          Icon(Icons.chevron_right, color: context.colors.textFaint, size: 20),
        ]),
      ),
    );
  }
}

// ── Etapa 2: Detalhe do produto + lista de lotes ──────────────────────────────

class _ProdutoDetail extends StatefulWidget {
  final UpdateViewModel vm;
  const _ProdutoDetail({required this.vm});
  @override State<_ProdutoDetail> createState() => _ProdutoDetailState();
}

class _ProdutoDetailState extends State<_ProdutoDetail>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _estoqueMinCtrl; // Para o estoque mínimo

  @override
  void initState() {
    super.initState();
    _tabs      = TabController(length: 2, vsync: this);
    _nomeCtrl    = TextEditingController(text: widget.vm.editNome);
    _descCtrl    = TextEditingController(text: widget.vm.editDescricao);
    _barcodeCtrl = TextEditingController(text: widget.vm.editCodigoBarras);
    _estoqueMinCtrl = TextEditingController(text: widget.vm.editEstoqueMinText);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _barcodeCtrl.dispose();
    _estoqueMinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UpdateViewModel>();
    return Column(children: [
      TabBar(
        controller: _tabs,
        labelColor: context.colors.accent,
        unselectedLabelColor: context.colors.textFaint,
        indicatorColor: context.colors.accent,
        tabs: const [
          Tab(icon: Icon(Icons.edit_outlined),   text: 'Dados'),
          Tab(icon: Icon(Icons.layers_outlined),  text: 'Lotes'),
        ],
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          // Aba dados do produto
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: vm.produtoFormKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
                _Field(label: 'Nome *', ctrl: _nomeCtrl,
                    icon: Icons.shopping_bag_outlined,
                    onSaved: (v) => vm.editNome = v ?? '',
                    validator: vm.validateNome,
                    capitalization: TextCapitalization.words),
                const SizedBox(height: 14),
                _Field(label: 'Descrição', ctrl: _descCtrl,
                    icon: Icons.description_outlined, maxLines: 3,
                    onSaved: (v) => vm.editDescricao = v ?? ''),
                const SizedBox(height: 14),
                _Field(label: 'Código de barras', ctrl: _barcodeCtrl,
                    icon: Icons.qr_code_outlined,
                    keyboardType: TextInputType.number,
                    onSaved: (v) => vm.editCodigoBarras = v ?? ''),
                const SizedBox(height: 14),
                _Field(label: 'Estoque mínimo', ctrl: _estoqueMinCtrl,
                    icon: Icons.warning_amber_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: vm.validateEstoqueMin,
                    onSaved: (v) => vm.editEstoqueMinText = v ?? ''),
                const SizedBox(height: 14),
                const _Label('Unidade de medida'),
                const SizedBox(height: 8),
                _Dropdown(
                  value: vm.editUnidade,
                  items: UpdateViewModel.unidades,
                  onChanged: vm.setUnidade,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: vm.isLoading ? null : () => vm.saveProduto(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: vm.isLoading
                        ? SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: context.colors.textPrimary, strokeWidth: 2.5))
                        : const Text('Salvar dados do produto',
                        style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
          // Aba lotes com botão "Adicionar novo lote"
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => vm.prepareNewLote(),
                    icon: const Icon(Icons.add, color: Color(0xFF1A1A2E)),
                    label: const Text('Adicionar novo lote',
                        style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: vm.lotes.isEmpty
                    ? Center(child: Text('Nenhum lote cadastrado.',
                    style: TextStyle(color: context.colors.textMuted)))
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.lotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _LoteTile(
                    lote: vm.lotes[i],
                    onTap: () => vm.selectLote(vm.lotes[i]),
                  ),
                ),
              ),
            ],
          ),
        ]),
      ),
    ]);
  }
}

class _LoteTile extends StatelessWidget {
  final Lote lote;
  final VoidCallback onTap;
  const _LoteTile({required this.lote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = lote.estaVencido ? Colors.redAccent : context.colors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.divider)),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.layers_outlined, color: context.colors.onPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lote.numeroLote ?? 'Lote #${lote.id}',
                style: TextStyle(color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Qtd: ${lote.quantidade} · Val: ${lote.validadeFormatada}',
                style: TextStyle(color: cor, fontSize: 12)),
            Text(lote.status.label,
                style: TextStyle(color: cor.withValues(alpha: 0.7), fontSize: 11)),
          ])),
          Icon(Icons.chevron_right, color: context.colors.textFaint, size: 20),
        ]),
      ),
    );
  }
}

// ── Etapa 3: Formulário de edição/criação do lote ─────────────────────────────

class _LoteForm extends StatefulWidget {
  final UpdateViewModel vm;
  const _LoteForm({required this.vm});
  @override State<_LoteForm> createState() => _LoteFormState();
}

class _LoteFormState extends State<_LoteForm> {
  late final TextEditingController _numCtrl;
  late final TextEditingController _qtdCtrl;
  late final TextEditingController _precoCtrl;

  @override
  void initState() {
    super.initState();
    _numCtrl   = TextEditingController(text: widget.vm.editNumeroLote);
    _qtdCtrl   = TextEditingController(text: widget.vm.editQuantidadeText);
    _precoCtrl = TextEditingController(text: widget.vm.editPrecoCustoText);
  }

  @override
  void dispose() {
    _numCtrl.dispose(); _qtdCtrl.dispose(); _precoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext ctx, {required bool isValidade}) async {
    final vm = ctx.read<UpdateViewModel>();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: (isValidade ? vm.editDataValidade : vm.editDataFabricacao)
          ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: ColorScheme.dark(
              primary: context.colors.accent, surface: context.colors.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      isValidade ? vm.setDataValidade(picked) : vm.setDataFabricacao(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UpdateViewModel>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: vm.loteFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // CORREÇÃO: Banner dinâmico informando se é edição ou inserção
          _InfoBanner(vm.selectedLote!.id == null
              ? 'Adicionando novo lote para:\n${vm.selectedProduto!.nome}'
              : 'Editando: ${vm.selectedLote!.numeroLote ?? 'Lote #${vm.selectedLote!.id}'}'),
          const SizedBox(height: 16),
          _Field(label: 'Nº do Lote', ctrl: _numCtrl,
              icon: Icons.tag_outlined,
              onSaved: (v) => vm.editNumeroLote = v ?? ''),
          const SizedBox(height: 14),
          _Field(label: 'Quantidade *', ctrl: _qtdCtrl,
              icon: Icons.numbers_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSaved: (v) => vm.editQuantidadeText = v ?? '',
              validator: vm.validateQuantidade),
          const SizedBox(height: 14),
          _Field(label: 'Preço de custo (R\$)', ctrl: _precoCtrl,
              icon: Icons.attach_money,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
              onSaved: (v) => vm.editPrecoCustoText = v ?? '',
              validator: vm.validatePrecoCusto),
          const SizedBox(height: 14),
          const _Label('Data de validade *'),
          const SizedBox(height: 8),
          _DateButton(date: vm.editDataValidade,
              hint: 'Selecionar data de validade',
              onTap: () => _pickDate(context, isValidade: true)),
          const SizedBox(height: 14),
          const _Label('Data de fabricação'),
          const SizedBox(height: 8),
          _DateButton(date: vm.editDataFabricacao,
              hint: 'Selecionar data de fabricação',
              onTap: () => _pickDate(context, isValidade: false)),
          const SizedBox(height: 14),
          const _Label('Status do lote'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LoteStatus>(
                value: vm.editStatusLote,
                isExpanded: true,
                dropdownColor: context.colors.surface,
                style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
                icon: Icon(Icons.keyboard_arrow_down, color: context.colors.accent),
                items: LoteStatus.values.map((s) =>
                    DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                onChanged: (s) => vm.setStatusLote(s!),
              ),
            ),
          ),
          if (vm.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(vm.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: vm.isLoading ? null : () => vm.saveLote(),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
                disabledBackgroundColor: context.colors.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: vm.isLoading
                  ? SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: context.colors.textPrimary, strokeWidth: 2.5))
                  : const Text('Salvar lote',
                  style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: context.colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500));
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.colors.primary.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.colors.primary.withValues(alpha: 0.5)),
    ),
    child: Row(children: [
      Icon(Icons.info_outline, color: context.colors.accent, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(color: context.colors.textSecondary, fontSize: 13))),
    ]),
  );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;

  const _Field({
    required this.label, required this.ctrl, required this.icon,
    this.maxLines = 1, this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.inputFormatters, this.onSaved, this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Label(label), const SizedBox(height: 8),
    TextFormField(
      controller: ctrl, maxLines: maxLines,
      keyboardType: keyboardType, textCapitalization: capitalization,
      inputFormatters: inputFormatters,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: context.colors.textFaint, size: 20),
        filled: true, fillColor: context.colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colors.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      onSaved: onSaved, validator: validator,
    ),
  ]);
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _Dropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, isExpanded: true, dropdownColor: context.colors.surface,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
        icon: Icon(Icons.keyboard_arrow_down, color: context.colors.accent),
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
      height: 52, padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: date != null ? context.colors.accent : Colors.transparent, width: 1.5),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today, color: context.colors.textFaint, size: 20),
        const SizedBox(width: 12),
        Text(_label, style: TextStyle(color: date == null ? context.colors.textFaint : context.colors.textPrimary, fontSize: 15)),
        const Spacer(),
        Icon(Icons.keyboard_arrow_down, color: context.colors.accent, size: 20),
      ]),
    ),
  );
}