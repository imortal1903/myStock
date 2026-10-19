import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/color_palette.dart';
import '../../../core/notificacoes/notificacao_config.dart';
import '../../../core/viewmodels/base_viewmodel.dart';
import '../../../core/notificacoes/notificacao_repository.dart';
import '../viewmodels/notificacao_viewmodel.dart';

class NotificacaoPage extends StatelessWidget {
  const NotificacaoPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        NotificacaoViewModel(notifRepo: NotificacaoRepository()),
    child: const _NotificacaoView(),
  );
}

class _NotificacaoView extends StatelessWidget {
  const _NotificacaoView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<NotificacaoViewModel>();

    final feedback = switch (vm.status) {
      ViewStatus.success => (
      'Configurações salvas e notificações agendadas!',
      colors.success
      ),
      ViewStatus.error when vm.errorMessage != null => (
      vm.errorMessage!,
      colors.danger
      ),
      _ => null,
    };

    if (feedback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(feedback.$1), backgroundColor: feedback.$2));
        context.read<NotificacaoViewModel>().resetStatus();
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
        title: Text('Notificações',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        centerTitle: true,
      ),
      body: vm.loading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : _NotificacaoBody(vm: vm),
    );
  }
}

class _NotificacaoBody extends StatelessWidget {
  final NotificacaoViewModel vm;
  const _NotificacaoBody({required this.vm});

  static String _intervaloShort(int h) => switch (h) {
    24 => 'Diário',
    48 => '2 dias',
    72 => '3 dias',
    168 => 'Semanal',
    _ => '${h}h',
  };

  Future<void> _pickTime(BuildContext context, NotificacaoConfig cfg) async {
    final colors = context.colors;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cfg.hora, minute: cfg.minuto),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
              primary: colors.accent, surface: colors.surface),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: colors.surface,
            hourMinuteColor: colors.bg,
            hourMinuteTextColor: colors.textPrimary,
            dialBackgroundColor: colors.bg,
            dialHandColor: colors.accent,
            dialTextColor: colors.textPrimary,
            entryModeIconColor: colors.accent,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) vm.setHorario(picked.hour, picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cfg = vm.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const SizedBox(height: 24),

          // Toggle principal
          _Card(
            child: Row(children: [
              Icon(Icons.notifications_active_outlined,
                  color: colors.accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ativar notificações',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text('Receber alertas de vencimento',
                        style: TextStyle(
                            color: colors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: cfg.ativado,
                onChanged: vm.setAtivado,
                activeThumbColor: colors.accent,
                inactiveTrackColor: colors.divider,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          AnimatedOpacity(
            opacity: cfg.ativado ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !cfg.ativado,
              child: Column(children: [
                // Dias antes
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RowLabel(
                        icon: Icons.calendar_today_outlined,
                        label: 'Avisar quantos dias antes?',
                        value:
                        '${cfg.diasAntes} dia${cfg.diasAntes > 1 ? 's' : ''}',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: NotificacaoConfig.opDiasAntes
                            .map((d) => _Chip(
                          label: '$d d',
                          selected: cfg.diasAntes == d,
                          onTap: () => vm.setDiasAntes(d),
                        ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Horário
                _Card(
                  child: _RowLabel(
                    icon: Icons.access_time_outlined,
                    label: 'Horário da notificação',
                    value: cfg.horarioLabel,
                    trailing: _TextButton(
                      label: 'Alterar',
                      onTap: () => _pickTime(context, cfg),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Intervalo
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RowLabel(
                        icon: Icons.repeat_outlined,
                        label: 'Repetir a cada',
                        value: cfg.intervaloLabel,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: NotificacaoConfig.opIntervaloHoras
                            .map((h) => _Chip(
                          label: _intervaloShort(h),
                          selected: cfg.intervaloHoras == h,
                          onTap: () => vm.setIntervalo(h),
                        ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _PreviewCard(config: cfg),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: vm.testar,
                  icon: Icon(Icons.send_outlined,
                      color: colors.accent, size: 18),
                  label: Text('Enviar notificação de teste',
                      style: TextStyle(color: colors.accent, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: vm.isSaving ? null : vm.salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                disabledBackgroundColor:
                colors.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: vm.isSaving
                  ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: colors.textPrimary, strokeWidth: 2.5),
              )
                  : const Text('Salvar e agendar',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

// Widgets privados
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.notifications_outlined,
            color: colors.onPrimary, size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Alertas de validade',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          Text('Receba avisos antes que seus produtos vençam.',
              style: TextStyle(color: colors.textMuted, fontSize: 13)),
        ]),
      ),
    ]);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.colors.divider),
    ),
    child: child,
  );
}

class _RowLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  const _RowLabel({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(children: [
      Icon(icon, color: colors.textMuted, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(color: colors.textMuted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              )),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

class _TextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
            color: context.colors.accent,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          )),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.2)
              : colors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.accent : colors.textGhost,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? colors.accent : colors.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            )),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final NotificacaoConfig config;
  const _PreviewCard({required this.config});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: TextStyle(
              color: colors.textSecondary, fontSize: 12, height: 1.5)),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.preview_outlined, color: colors.accent, size: 16),
          const SizedBox(width: 8),
          Text('Como vai funcionar',
              style: TextStyle(
                color: colors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
        ]),
        const SizedBox(height: 10),
        line('• Primeiro aviso ${config.diasAntes} '
            'dia${config.diasAntes > 1 ? 's' : ''} antes do vencimento, '
            'às ${config.horarioLabel}'),
        line('• Repetido ${config.intervaloLabel.toLowerCase()} '
            'até a data de validade'),
        line('• Máximo de 20 notificações por produto'),
      ]),
    );
  }
}