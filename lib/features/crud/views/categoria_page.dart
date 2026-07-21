import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categoria.dart';
import '../viewmodels/categoria_viewmodel.dart';
// Ajuste o caminho abaixo conforme a localização real do color_palette.dart
// no seu projeto (ex.: '../../../core/theme/color_palette.dart').
import '../../../core/theme/color_palette.dart';

class CategoriaPage extends StatelessWidget {
  const CategoriaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CategoriaViewModel(),
      child: const _CategoriaView(),
    );
  }
}

class _CategoriaView extends StatelessWidget {
  const _CategoriaView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<CategoriaViewModel>();

    // Mostra o erro (ex.: falha ao excluir) em um SnackBar, uma única vez.
    if (vm.status == CategoriaStatus.error && vm.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(vm.errorMessage!),
            backgroundColor: colors.danger,
          ));
        vm.resetStatus();
      });
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('Categorias', style: TextStyle(color: colors.textPrimary)),
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: vm.loadCategorias,
        child: _buildBody(context, vm, colors),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        onPressed: () => _showFormSheet(context, vm, colors),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      CategoriaViewModel vm,
      ColorPalette colors,
      ) {
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
            child: Text(
              'Nenhuma categoria cadastrada',
              style: TextStyle(color: colors.textMuted, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Toque em "+" para criar a primeira',
              style: TextStyle(color: colors.textFaint, fontSize: 13),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: vm.categorias.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final categoria = vm.categorias[index];
        return _CategoriaTile(
          categoria: categoria,
          colors: colors,
          onEdit: () => _showFormSheet(context, vm, colors, categoria: categoria),
          onDelete: () => _confirmDelete(context, vm, colors, categoria),
        );
      },
    );
  }

  // ── Bottom sheet: criar / editar ──────────────────────────────────────────

  void _showFormSheet(
      BuildContext context,
      CategoriaViewModel vm,
      ColorPalette colors, {
        Categoria? categoria,
      }) {
    if (categoria != null) {
      vm.selectForEdit(categoria);
    } else {
      vm.startNew();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: _CategoriaForm(vm: vm, colors: colors),
        );
      },
    ).whenComplete(vm.cancelEdit);
  }

  // ── Confirmação de exclusão ────────────────────────────────────────────────

  void _confirmDelete(
      BuildContext context,
      CategoriaViewModel vm,
      ColorPalette colors,
      Categoria categoria,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Excluir categoria', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Deseja excluir "${categoria.nome}"? Essa ação não pode ser desfeita.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancelar', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await vm.delete(categoria.id!);
            },
            child: Text('Excluir', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Item da lista ──────────────────────────────────────────────────────────

class _CategoriaTile extends StatelessWidget {
  final Categoria categoria;
  final ColorPalette colors;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoriaTile({
    required this.categoria,
    required this.colors,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: 0.15),
                foregroundColor: colors.primary,
                child: const Icon(Icons.category_outlined, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  categoria.nome,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: colors.textMuted, size: 20),
                onPressed: onEdit,
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colors.danger, size: 20),
                onPressed: onDelete,
                tooltip: 'Excluir',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Formulário de criação / edição ────────────────────────────────────────

class _CategoriaForm extends StatefulWidget {
  final CategoriaViewModel vm;
  final ColorPalette colors;

  const _CategoriaForm({required this.vm, required this.colors});

  @override
  State<_CategoriaForm> createState() => _CategoriaFormState();
}

class _CategoriaFormState extends State<_CategoriaForm> {
  late final TextEditingController _nomeController;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.vm.nome);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final colors = widget.colors;

    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        return Form(
          key: vm.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vm.isEditing ? 'Editar categoria' : 'Nova categoria',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
                validator: vm.validateNome,
                onChanged: (v) => vm.nome = v,
                onSaved: (v) => vm.nome = v?.trim() ?? '',
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(context, vm),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: vm.isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textMuted,
                        side: BorderSide(color: colors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: vm.isLoading ? null : () => _save(context, vm),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: vm.isLoading
                          ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                          : const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(BuildContext context, CategoriaViewModel vm) async {
    final ok = await vm.save();
    if (ok && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}