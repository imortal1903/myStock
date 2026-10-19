import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/color_palette.dart';
import 'exportar_page.dart';
import '../viewmodels/config_viewmodel.dart';
import '../viewmodels/backup_viewmodel.dart';
import '../../../core/backup/backup_config.dart';

// Página de Configurações
class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(children: [
          const _TopBar(),
          Expanded(
            child: Consumer<ConfigViewModel>(
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
                    const _SectionTitle('Backup'),
                    const SizedBox(height: 12),
                    const _BackupSection(),
                    const SizedBox(height: 28),
                    const _SectionTitle('Sobre'),
                    const SizedBox(height: 12),
                    const _SobreSection(),
                    const SizedBox(height: 28),
                    const _SectionTitle('Dados'),
                    const SizedBox(height: 12),
                    _DadosSection(vm: vm),
                    const SizedBox(height: 28),
                    const _SectionTitle('Exportar'),
                    const SizedBox(height: 12),
                    const _ExportarSection(),
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

// Top Bar
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
        const SizedBox(width: 48),
      ]),
    );
  }
}

// Título de seção
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(title,
      style: TextStyle(
          color: context.colors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0));
}

// Card base
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
    child: child,
  );
}

// Seção: Aparência

class _AparenciaSection extends StatelessWidget {
  final ConfigViewModel vm;
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

// Seção: Backup em nuvem
class _BackupSection extends StatelessWidget {
  const _BackupSection();

  String _formatarDataHora(DateTime? d) {
    if (d == null) return 'Nunca';
    final agora = DateTime.now();
    final hoje =
        agora.year == d.year && agora.month == d.month && agora.day == d.day;
    final hora =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (hoje) return 'Hoje às $hora';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year} às $hora';
  }

  String _formatarProximoBackup(BackupConfig config) {
    if (config.ultimoBackupEm == null || !config.ativado) return '';
    final proximo = config.ultimoBackupEm!.add(Duration(minutes: config.intervaloMinutos));
    final hora = proximo.hour.toString().padLeft(2, '0');
    final minuto = proximo.minute.toString().padLeft(2, '0');
    return ' ($hora:$minuto)';
  }

  /// Opções fixas oferecidas ao usuário
  /// todas >= kIntervaloMinimoMinutos.
  static const _opcoesIntervalo = <int>[
    kIntervaloMinimoMinutos,
    30,
    60,
    3 * 60,
    6 * 60,
    12 * 60,
    24 * 60,
  ];

  String _formatarIntervalo(int minutos) {
    if (minutos < 60) return 'A cada $minutos minutos';
    if (minutos == 60) return 'A cada 1 hora';
    if (minutos % (24 * 60) == 0) {
      final dias = minutos ~/ (24 * 60);
      return dias == 1 ? '1x por dia' : 'A cada $dias dias';
    }
    final horas = minutos ~/ 60;
    return 'A cada $horas horas';
  }

  Future<void> _escolherIntervalo(BuildContext context, BackupViewModel vm) async {
    final escolhido = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Text('Intervalo entre backups automáticos',
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'O Android não permite menos de $kIntervaloMinimoMinutos minutos '
                    'entre execuções — é um limite do próprio sistema.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textFaint, fontSize: 11.5),
              ),
            ),
            const SizedBox(height: 8),
            ..._opcoesIntervalo.map((minutos) => ListTile(
              title: Text(_formatarIntervalo(minutos),
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: vm.config.intervaloMinutos == minutos
                  ? Icon(Icons.check, color: context.colors.accent)
                  : null,
              onTap: () => Navigator.pop(ctx, minutos),
            )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (escolhido != null) vm.definirIntervalo(escolhido);
  }

  Future<void> _confirmarRestaurar(BuildContext context, BackupViewModel vm) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Restaurar backup da nuvem?',
            style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'Isso vai SUBSTITUIR todos os produtos, lotes e vendas atuais pelos '
              'dados do último backup salvo no Google Drive. Essa ação não pode '
              'ser desfeita.',
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
    if (confirmou != true) return;

    final ok = await vm.restaurarBackup();
    if (!context.mounted) return;

    if (ok) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Backup restaurado', style: TextStyle(color: context.colors.textPrimary)),
          content: Text(
            'Feche e abra o myStock novamente para ver os dados restaurados.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ok')),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage ?? 'Não foi possível restaurar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BackupViewModel>(
      create: (_) => BackupViewModel(),
      child: Consumer<BackupViewModel>(
        builder: (context, vm, _) {
          final config = vm.config;
          return _Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.cloud_outlined, color: context.colors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Backup em nuvem (Google Drive)',
                        style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                  Switch(
                    value: config.ativado,
                    activeThumbColor: context.colors.accent,
                    onChanged: vm.isLoading
                        ? null
                        : (v) => v ? vm.ativar() : vm.desativar(),
                  ),
                ]),
                if (vm.isLoading) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: context.colors.accent)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          config.ativado
                              ? 'Desativando...'
                              : 'Conectando com o Google e enviando o primeiro backup...',
                          style: TextStyle(color: context.colors.textFaint, fontSize: 12)),
                    ),
                  ]),
                ],
                if (vm.hasError) ...[
                  const SizedBox(height: 10),
                  Text(vm.errorMessage ?? '',
                      style: TextStyle(color: context.colors.danger, fontSize: 12)),
                ],
                if (config.ativado) ...[
                  const SizedBox(height: 14),
                  Container(
                      height: 1, color: context.colors.textPrimary.withValues(alpha: 0.06)),
                  const SizedBox(height: 14),
                  if (config.contaEmail != null) ...[
                    _InfoRow(label: 'Conta conectada', value: config.contaEmail!),
                    const SizedBox(height: 10),
                  ],
                  _InfoRow(
                      label: 'Último backup enviado',
                      value: _formatarDataHora(config.ultimoBackupEm)),
                  const SizedBox(height: 10),
                  _InfoRow(
                      label: 'Última verificação do sistema',
                      value: _formatarDataHora(config.ultimaTentativaEm)),
                  const SizedBox(height: 10),
                  if (config.ultimoErro != null) ...[
                    Text('Último erro de execução:',
                        style: TextStyle(color: context.colors.danger, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(config.ultimoErro!,
                        style: TextStyle(
                            color: context.colors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                  ],
                  GestureDetector(
                    onTap: () => _escolherIntervalo(context, vm),
                    child: _InfoRow(
                      label: 'Intervalo entre backups (toque para alterar)',
                      value: '${_formatarIntervalo(config.intervaloMinutos)}${_formatarProximoBackup(config)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: vm.fazendoBackup ? null : vm.fazerBackupAgora,
                    icon: vm.fazendoBackup
                        ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: context.colors.accent))
                        : Icon(Icons.backup_outlined, size: 18, color: context.colors.accent),
                    label: Text('Fazer backup agora',
                        style: TextStyle(color: context.colors.accent)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(color: context.colors.accent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed:
                    vm.restaurando ? null : () => _confirmarRestaurar(context, vm),
                    icon: vm.restaurando
                        ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: context.colors.danger))
                        : Icon(Icons.cloud_download_outlined,
                        size: 18, color: context.colors.danger),
                    label: Text('Restaurar backup',
                        style: TextStyle(color: context.colors.danger)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(color: context.colors.danger),
                    ),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}



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

// Seção: Dados
class _DadosSection extends StatelessWidget {
  final ConfigViewModel vm;
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

  Future<void> _confirmarGerarDados(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Gerar dados de teste?', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'ATENÇÃO: Isso apagará TODOS os dados atuais (produtos, vendas, lotes) '
              'e criará um histórico simulado de 1 ano. Esta ação é irreversível.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Gerar Dados', style: TextStyle(color: context.colors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await vm.gerarDadosTeste();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados de teste gerados com sucesso!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(children: [
        InkWell(
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
        Container(height: 1, color: context.colors.textPrimary.withValues(alpha: 0.06)),
        InkWell(
          onTap: vm.isGeneratingData ? null : () => _confirmarGerarDados(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              vm.isGeneratingData
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.accent),
              )
                  : Icon(Icons.analytics_outlined, color: context.colors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  vm.isGeneratingData ? 'Gerando histórico...' : 'Gerar histórico de teste (1 ano)',
                  style: TextStyle(
                    color: vm.isGeneratingData ? context.colors.textFaint : context.colors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!vm.isGeneratingData) Icon(Icons.chevron_right, color: context.colors.textGhost, size: 20),
            ]),
          ),
        ),
      ]),
    );
  }
}

// Seção: Exportar
class _ExportarSection extends StatelessWidget {
  const _ExportarSection();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExportarPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.ios_share_rounded,
                  color: context.colors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exportar relatório',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    'Escolha um modelo ou marque as tabelas e informações. '
                        'Saída em CSV ou PDF, para salvar ou compartilhar.',
                    style: TextStyle(
                      color: context.colors.textFaint,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: context.colors.textGhost, size: 20),
          ]),
        ),
      ),
    );
  }
}