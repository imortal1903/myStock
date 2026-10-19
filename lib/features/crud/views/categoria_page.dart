import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categoria.dart';
import '../viewmodels/categoria_viewmodel.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class CategoriaPage extends StatelessWidget {
  const CategoriaPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => CategoriaViewModel(),
    child: const _CategoriaView(),
  );
}

class _CategoriaView extends StatelessWidget {
  const _CategoriaView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<CategoriaViewModel>();

    if (vm.status == ViewStatus.error && vm.errorMessage != null) {
      final msg = vm.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(msg), backgroundColor: colors.danger));
        context.read<CategoriaViewModel>().resetStatus();
      });
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: colors.textSecondary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Categorias',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: vm.loadCategorias,
        child: _Body(vm: vm),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        onPressed: () => showCategoriaFormSheet(context, vm),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Abre o bottom sheet de criação/edição.
void showCategoriaFormSheet(
    BuildContext context,
    CategoriaViewModel vm, {
      Categoria? categoria,
    }) {
  categoria != null ? vm.selectForEdit(categoria) : vm.startNew();

  showModalBottomSheet(
    context: context,
    backgroundColor: context.colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
      ),
      // O sheet vive fora da árvore da página: repassamos o VM explicitamente.
      child: ChangeNotifierProvider.value(
        value: vm,
        child: const _CategoriaForm(),
      ),
    ),
  ).whenComplete(vm.cancelEdit);
}

class _Body extends StatelessWidget {
  final CategoriaViewModel vm;
  const _Body({required this.vm});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (vm.isLoading && vm.categorias.isEmpty) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (vm.categorias.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Icon(Icons.category_outlined, size: 56, color: colors.textFaint),
          const SizedBox(height: 16),
          Center(
            child: Text('Nenhuma categoria cadastrada',
                style: TextStyle(color: colors.textMuted, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Toque em "+" para criar a primeira',
                style: TextStyle(color: colors.textFaint, fontSize: 13)),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: vm.categorias.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final categoria = vm.categorias[index];
        return _CategoriaTile(
          categoria: categoria,
          onEdit: () =>
              showCategoriaFormSheet(ctx, vm, categoria: categoria),
          onDelete: () => _confirmDelete(ctx, vm, categoria),
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, CategoriaViewModel vm, Categoria categoria) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Excluir categoria',
            style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Deseja excluir "${categoria.nome}"? Essa ação não pode ser desfeita.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
            Text('Cancelar', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              vm.delete(categoria.id!);
            },
            child: Text('Excluir', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
  }
}

class _CategoriaTile extends StatelessWidget {
  final Categoria categoria;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CategoriaTile({
    required this.categoria,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: colors.primary.withValues(alpha: 0.15),
              foregroundColor: colors.primary,
              child: const Icon(Icons.category_outlined, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(categoria.nome,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  )),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: colors.textMuted, size: 20),
              onPressed: onEdit,
              tooltip: 'Editar',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colors.danger, size: 20),
              onPressed: onDelete,
              tooltip: 'Excluir',
            ),
          ]),
        ),
      ),
    );
  }
}

// Formulário

class _CategoriaForm extends StatefulWidget {
  const _CategoriaForm();
  @override
  State<_CategoriaForm> createState() => _CategoriaFormState();
}

class _CategoriaFormState extends State<_CategoriaForm> {
  late final TextEditingController _nomeController =
  TextEditingController(text: context.read<CategoriaViewModel>().nome);

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vm = context.read<CategoriaViewModel>();
    final navigator = Navigator.of(context);
    if (await vm.save() && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<CategoriaViewModel>();

    OutlineInputBorder border(Color? c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
      c == null ? BorderSide.none : BorderSide(color: c, width: 1.5),
    );

    return Form(
      key: vm.formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(vm.isEditing ? 'Editar categoria' : 'Nova categoria',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nomeController,
            autofocus: true,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Nome da categoria',
              labelStyle: TextStyle(color: colors.textMuted),
              filled: true,
              fillColor: colors.bg,
              border: border(null),
              focusedBorder: border(colors.primary),
            ),
            validator: vm.validateNome,
            onChanged: (v) => vm.nome = v,
            onSaved: (v) => vm.nome = v?.trim() ?? '',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                vm.isLoading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textMuted,
                  side: BorderSide(color: colors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: vm.isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: vm.isLoading
                    ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.onPrimary),
                )
                    : const Text('Salvar'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}