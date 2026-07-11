import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../viewmodels/settings_viewmodel.dart';

// ─── Página de Configurações ───────────────────────────────────────────────

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(children: [
          const _TopBar(),
          Expanded(
            child: Consumer<SettingsViewModel>(
              builder: (context, vm, _) {
                if (vm.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(color: context.colors.accent),
                  );
                }
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _SectionTitle('Aparência'),
                    const SizedBox(height: 12),
                    _AparenciaSection(vm: vm),
                    const SizedBox(height: 28),
                    const _SectionTitle('Sobre'),
                    const SizedBox(height: 12),
                    const _SobreSection(),
                    const SizedBox(height: 28),
                    const _SectionTitle('Dados'),
                    const SizedBox(height: 12),
                    _DadosSection(vm: vm),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Top Bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_ios_new, color: context.colors.textPrimary, size: 18),
        ),
        Expanded(
          child: Text('Configurações',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        const SizedBox(width: 48), // balanceia o botão de voltar
      ]),
    );
  }
}

// ─── Título de seção ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(title,
      style: TextStyle(
          color: context.colors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0));
}

// ─── Card base ──────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
    child: child,
  );
}

// ─── Seção: Aparência ───────────────────────────────────────────────────────

class _AparenciaSection extends StatelessWidget {
  final SettingsViewModel vm;
  const _AparenciaSection({required this.vm});

  static const _opcoes = [
    (mode: ThemeMode.light, icon: Icons.light_mode_outlined, label: 'Claro'),
    (mode: ThemeMode.dark, icon: Icons.dark_mode_outlined, label: 'Escuro'),
    (mode: ThemeMode.system, icon: Icons.brightness_auto_outlined, label: 'Sistema'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: _opcoes.map((o) {
            final selecionado = vm.themeMode == o.mode;
            return Expanded(
              child: GestureDetector(
                onTap: () => vm.definirTema(o.mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: selecionado
                        ? context.colors.accent.withValues(alpha: 0.15)
                        : context.colors.primary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selecionado ? context.colors.accent : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(o.icon, color: selecionado ? context.colors.accent : context.colors.textMuted, size: 22),
                    const SizedBox(height: 6),
                    Text(o.label,
                        style: TextStyle(
                            color: selecionado ? context.colors.accent : context.colors.textMuted,
                            fontSize: 12,
                            fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Seção: Sobre ───────────────────────────────────────────────────────────

class _SobreSection extends StatelessWidget {
  const _SobreSection();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.inventory_2_outlined, color: context.colors.onPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('myStock', style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Versão 1.0.0', style: TextStyle(color: context.colors.textFaint, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 14),
          Text(
            'Aplicativo gratuito e de código aberto para gestão de estoque e vendas, '
                'voltado a pequenos e microempreendedores brasileiros.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: context.colors.textPrimary.withValues(alpha: 0.06)),
          const SizedBox(height: 14),
          const _InfoRow(label: 'Trabalho de Conclusão de Curso', value: 'Curso Técnico em Desenvolvimento de Sistemas'),
          const SizedBox(height: 8),
          const _InfoRow(label: 'Instituição', value: 'IFRS – Campus Canoas'),
          const SizedBox(height: 8),
          const _InfoRow(label: 'Orientador', value: 'Prof. Dr. Dieison Soares Silveira'),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(color: context.colors.textFaint, fontSize: 11)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(color: context.colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
  ]);
}

// ─── Seção: Dados ───────────────────────────────────────────────────────────

class _DadosSection extends StatelessWidget {
  final SettingsViewModel vm;
  const _DadosSection({required this.vm});

  Future<void> _confirmarRestaurar(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Restaurar padrões?', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'Isso vai redefinir o tema e os valores padrão de notificação. '
              'Seus produtos, lotes e vendas não serão afetados.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restaurar', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await vm.restaurarPadroes();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações restauradas.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _confirmarRestaurar(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(Icons.restore_outlined, color: context.colors.danger, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Restaurar configurações padrão',
                  style: TextStyle(color: context.colors.danger, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, color: context.colors.textGhost, size: 20),
          ]),
        ),
      ),
    );
  }
}