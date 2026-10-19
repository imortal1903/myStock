import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lote.dart';
import '../models/produto.dart';
import '../models/estoque_resumo.dart';
import '../viewmodels/update_viewmodel.dart';
import 'widgets/form_widgets.dart';
import 'widgets/lote_tile.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class UpdatePage extends StatelessWidget {
  final Produto? produto;
  final Lote? loteInicial;

  const UpdatePage({super.key, this.produto, this.loteInicial});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => UpdateViewModel(
      initialProduto: produto,
      initialLote: loteInicial,
    ),
    child: const _UpdateView(),
  );
}

class _UpdateView extends StatelessWidget {
  const _UpdateView();

  String _title(UpdateViewModel vm) {
    if (vm.selectedLote != null) {
      return vm.selectedLote!.id == null ? 'Novo Lote' : 'Editar Lote';
    }
    if (vm.selectedProduto != null) {
      return 'Produto: ${vm.selectedProduto!.nome}';
    }
    return 'Selecionar Produto';
  }

  void _onBack(BuildContext context) {
    final vm = context.read<UpdateViewModel>();
    if (vm.selectedLote != null) {
      if (vm.abriuComLoteEspecifico) {
        // Aberto direto de um lote (via ProdutoDetailPage) - "voltar"
        // aqui significa sair da tela inteira, não cair na visão normal
        // (abas "Dados"/"Lotes") do UpdatePage.
        Navigator.pop(context);
      } else {
        vm.clearLoteSelection();
      }
    } else if (vm.selectedProduto != null && !vm.abriuComProdutoEspecifico) {
      vm.clearProdutoSelection();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UpdateViewModel>();

    if (vm.status == ViewStatus.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final vmAtual = context.read<UpdateViewModel>();
        // O caso "salvou um lote aberto direto de ProdutoDetailPage" já é
        // tratado em _LoteFormState._salvar() (que decide na hora, sem
        // esperar um rebuild) e reseta o status antes de chegar aqui.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Salvo com sucesso!'),
          backgroundColor: context.colors.primary,
        ));
        vmAtual.resetStatus();
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
          onPressed: () => _onBack(context),
        ),
        title: Text(
          _title(vm),
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: vm.selectedLote != null
          ? _LoteForm(key: ValueKey(vm.selectedLote), vm: vm)
          : vm.selectedProduto != null
          ? _ProdutoDetail(key: ValueKey(vm.selectedProduto!.id), vm: vm)
          : _ProductList(vm: vm),
    );
  }
}

// Lista de produtos
class _ProductList extends StatelessWidget {
  final UpdateViewModel vm;
  const _ProductList({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading && vm.produtos.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: context.colors.accent));
    }
    if (vm.produtos.isEmpty) {
      return Center(
        child: Text('Nenhum produto cadastrado.',
            style: TextStyle(color: context.colors.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vm.produtos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ProductTile(
        produto: vm.produtos[i],
        estoque: vm.estoqueDe(vm.produtos[i]),
        onTap: () => vm.selectProduto(vm.produtos[i]),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Produto produto;
  final EstoqueResumo estoque;
  final VoidCallback onTap;
  const _ProductTile({
    required this.produto,
    required this.estoque,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color badgeCor;
    final String badgeTexto;

    if (estoque.disponivel) {
      badgeCor = colors.success;
      badgeTexto = 'Qtd: ${estoque.quantidadeAtiva}';
    } else if (estoque.vencido) {
      badgeCor = colors.danger;
      badgeTexto = 'Vencido';
    } else {
      badgeCor = Colors.orangeAccent;
      badgeTexto = 'Esgotado';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_outlined,
                color: colors.onPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(produto.nome,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 4),
                Row(children: [
                  Text(
                    '${produto.unidade} · ${produto.ativo ? "Ativo" : "Inativo"}',
                    style: TextStyle(color: colors.accent, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeCor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badgeTexto,
                        style: TextStyle(
                          color: badgeCor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ]),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textFaint, size: 20),
        ]),
      ),
    );
  }
}

// Dados do produto + lotes
class _ProdutoDetail extends StatefulWidget {
  final UpdateViewModel vm;
  const _ProdutoDetail({super.key, required this.vm});
  @override
  State<_ProdutoDetail> createState() => _ProdutoDetailState();
}

class _ProdutoDetailState extends State<_ProdutoDetail>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  late final _nomeCtrl = TextEditingController(text: widget.vm.editNome);
  late final _descCtrl = TextEditingController(text: widget.vm.editDescricao);
  late final _barcodeCtrl =
  TextEditingController(text: widget.vm.editCodigoBarras);
  late final _estoqueMinCtrl =
  TextEditingController(text: widget.vm.editEstoqueMinText);

  late final List<TextEditingController> _allCtrls = [
    _nomeCtrl,
    _descCtrl,
    _barcodeCtrl,
    _estoqueMinCtrl,
  ];

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _allCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UpdateViewModel>();
    final colors = context.colors;

    return Column(children: [
      TabBar(
        controller: _tabs,
        labelColor: colors.accent,
        unselectedLabelColor: colors.textFaint,
        indicatorColor: colors.accent,
        tabs: const [
          Tab(icon: Icon(Icons.edit_outlined), text: 'Dados'),
          Tab(icon: Icon(Icons.layers_outlined), text: 'Lotes'),
        ],
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _dadosTab(context, vm),
          _lotesTab(context, vm),
        ]),
      ),
    ]);
  }

  Widget _dadosTab(BuildContext context, UpdateViewModel vm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: vm.produtoFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormField_(
              label: 'Nome *',
              ctrl: _nomeCtrl,
              icon: Icons.shopping_bag_outlined,
              capitalization: TextCapitalization.words,
              validator: vm.validateNome,
              onSaved: (v) => vm.editNome = v ?? '',
            ),
            const SizedBox(height: 14),
            FormField_(
              label: 'Descrição',
              ctrl: _descCtrl,
              icon: Icons.description_outlined,
              maxLines: 3,
              onSaved: (v) => vm.editDescricao = v ?? '',
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FormField_(
                    label: 'Código de barras',
                    ctrl: _barcodeCtrl,
                    icon: Icons.qr_code_outlined,
                    keyboardType: TextInputType.number,
                    validator: vm.validateCodigoBarras,
                    onChanged: (v) => vm.editCodigoBarras = v,
                    onSaved: (v) => vm.editCodigoBarras = v ?? '',
                  ),
                ),
                const SizedBox(width: 10),
                ScanButton(
                  onScanned: (codigo) {
                    _barcodeCtrl.text = codigo;
                    vm.editCodigoBarras = codigo;
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            FormField_(
              label: 'Estoque mínimo',
              ctrl: _estoqueMinCtrl,
              icon: Icons.warning_amber_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: FormFormatters.digits,
              validator: vm.validateEstoqueMin,
              onSaved: (v) => vm.editEstoqueMinText = v ?? '',
            ),
            const SizedBox(height: 14),
            const FormLabel('Unidade de medida'),
            const SizedBox(height: 8),
            FormDropdown.strings(
              value: vm.editUnidade,
              items: UpdateViewModel.unidades,
              onChanged: vm.setUnidade,
            ),
            const SizedBox(height: 14),
            const FormLabel('Categoria'),
            const SizedBox(height: 8),
            if (vm.categorias.isEmpty)
              const CategoriaEmptyWarning()
            else
              FormDropdown<int?>(
                value: vm.editCategoriaId,
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
            const SizedBox(height: 14),
            _PrimaryButton(
              label: 'Salvar dados do produto',
              isLoading: vm.isLoading,
              onPressed: vm.saveProduto,
            ),
          ],
        ),
      ),
    );
  }

  Widget _lotesTab(BuildContext context, UpdateViewModel vm) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: vm.prepareNewLote,
            icon: const Icon(Icons.add, color: Color(0xFF1A1A2E)),
            label: const Text('Adicionar novo lote',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                )),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.accent,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ),
      Expanded(
        child: vm.lotes.isEmpty
            ? Center(
          child: Text('Nenhum lote cadastrado.',
              style: TextStyle(color: context.colors.textMuted)),
        )
            : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: vm.lotes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => LoteTile(
            lote: vm.lotes[i],
            onTap: () => vm.selectLote(vm.lotes[i]),
          ),
        ),
      ),
    ]);
  }
}

// Formulário do lote
class _LoteForm extends StatefulWidget {
  final UpdateViewModel vm;
  const _LoteForm({super.key, required this.vm});
  @override
  State<_LoteForm> createState() => _LoteFormState();
}

class _LoteFormState extends State<_LoteForm> {
  late final _numCtrl = TextEditingController(text: widget.vm.editNumeroLote);
  late final _qtdCtrl =
  TextEditingController(text: widget.vm.editQuantidadeText);
  late final _precoCustoCtrl =
  TextEditingController(text: widget.vm.editPrecoCustoText);
  late final _precoVendaCtrl =
  TextEditingController(text: widget.vm.editPrecoVendaText);

  late final List<TextEditingController> _allCtrls = [
    _numCtrl,
    _qtdCtrl,
    _precoCustoCtrl,
    _precoVendaCtrl,
  ];

  @override
  void dispose() {
    for (final c in _allCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isValidade}) async {
    final vm = context.read<UpdateViewModel>();
    final picked = await showDatePicker(
      context: context,
      initialDate:
      (isValidade ? vm.editDataValidade : vm.editDataFabricacao) ??
          DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (c, child) => buildThemedDatePicker(c, child!),
    );
    if (picked == null) return;
    isValidade ? vm.setDataValidade(picked) : vm.setDataFabricacao(picked);
  }

  /// Aguarda o saveLote() terminar e decide aqui mesmo, de forma direta
  /// e síncrona com o resultado, se deve fechar a tela e voltar para
  /// ProdutoDetailPage.
  Future<void> _salvar(BuildContext context, UpdateViewModel vm) async {
    await vm.saveLote();
    if (!context.mounted) return;

    final devefechar = vm.status == ViewStatus.success &&
        vm.ultimoSaveFoiDeLote &&
        vm.abriuComLoteEspecifico;

    if (devefechar) {
      vm.resetStatus();
      vm.limparUltimoSaveFoiDeLote();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UpdateViewModel>();
    final lote = vm.selectedLote;
    if (lote == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: vm.loteFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoBanner(
              lote.id == null
                  ? 'Adicionando novo lote para:\n${vm.selectedProduto?.nome ?? ''}'
                  : 'Editando: ${lote.numeroLote ?? 'Lote #${lote.id}'}',
            ),
            const SizedBox(height: 16),
            FormField_(
              label: 'Nº do Lote',
              ctrl: _numCtrl,
              icon: Icons.tag_outlined,
              onSaved: (v) => vm.editNumeroLote = v ?? '',
            ),
            const SizedBox(height: 14),
            FormField_(
              label: vm.permiteFracao
                  ? 'Quantidade * (aceita decimal, ex.: 1,5)'
                  : 'Quantidade *',
              ctrl: _qtdCtrl,
              icon: Icons.numbers_outlined,
              keyboardType: vm.permiteFracao
                  ? FormFormatters.decimalKeyboard
                  : TextInputType.number,
              inputFormatters:
              vm.permiteFracao ? FormFormatters.decimal : FormFormatters.digits,
              validator: vm.validateQuantidade,
              onChanged: (v) => vm.editQuantidadeText = v,
              onSaved: (v) => vm.editQuantidadeText = v ?? '',
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormField_(
                    label: 'Preço de custo (R\u0024) *',
                    ctrl: _precoCustoCtrl,
                    icon: Icons.attach_money,
                    keyboardType: FormFormatters.decimalKeyboard,
                    inputFormatters: FormFormatters.decimal,
                    validator: vm.validatePrecoCusto,
                    onSaved: (v) => vm.editPrecoCustoText = v ?? '',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FormField_(
                    label: 'Preço de venda (R\u0024) *',
                    ctrl: _precoVendaCtrl,
                    icon: Icons.sell_outlined,
                    keyboardType: FormFormatters.decimalKeyboard,
                    inputFormatters: FormFormatters.decimal,
                    validator: vm.validatePrecoVenda,
                    onSaved: (v) => vm.editPrecoVendaText = v ?? '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FormLabel('Data de validade *'),
            const SizedBox(height: 8),
            DateButton(
              date: vm.editDataValidade,
              hint: 'Selecionar data de validade',
              onTap: () => _pickDate(isValidade: true),
            ),
            const SizedBox(height: 14),
            const FormLabel('Data de fabricação'),
            const SizedBox(height: 8),
            DateButton(
              date: vm.editDataFabricacao,
              hint: 'Selecionar data de fabricação',
              onTap: () => _pickDate(isValidade: false),
            ),
            const SizedBox(height: 14),
            const FormLabel('Data de entrada'),
            const SizedBox(height: 8),
            DateButton(
              date: vm.editDataEntrada,
              hint: 'Hoje',
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: vm.editDataEntrada,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  builder: (c, child) => buildThemedDatePicker(c, child!),
                );
                if (picked != null) vm.setDataEntrada(picked);
              },
            ),
            const SizedBox(height: 14),
            const FormLabel('Status do lote'),
            const SizedBox(height: 8),
            FormDropdown<LoteStatus>(
              value: vm.editStatusLote,
              onChanged: (s) {
                if (s != null) vm.setStatusLote(s);
              },
              items: LoteStatus.values
                  .map((s) =>
                  DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
            ),
            if (vm.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(vm.errorMessage!,
                  style:
                  const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'Salvar lote',
              isLoading: vm.isLoading,
              onPressed: () => _salvar(context, vm),
            ),
          ],
        ),
      ),
    );
  }
}

// Widgets locais
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: context.colors.accent,
        disabledBackgroundColor:
        context.colors.accent.withValues(alpha: 0.5),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: isLoading
          ? SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
            color: context.colors.textPrimary, strokeWidth: 2.5),
      )
          : Text(label,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          )),
    ),
  );
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
      border:
      Border.all(color: context.colors.primary.withValues(alpha: 0.5)),
    ),
    child: Row(children: [
      Icon(Icons.info_outline, color: context.colors.accent, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: TextStyle(
                color: context.colors.textSecondary, fontSize: 13)),
      ),
    ]),
  );
}