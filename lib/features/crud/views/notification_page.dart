import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';

import '../../../core/notifications/notification_config.dart';
import '../repositories/notification_repository.dart';
import '../viewmodels/notification_viewmodel.dart';

// ─── Notification Page ────────────────────────────────────────────────────────

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationViewModel(
        notifRepo: NotificacaoRepository(),
      ),
      child: const _NotificationView(),
    );
  }
}

// ─── View ─────────────────────────────────────────────────────────────────────

class _NotificationView extends StatelessWidget {
  const _NotificationView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationViewModel>();

    // Feedback via SnackBar
    if (vm.status == NotifSaveStatus.saved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas e notificações agendadas!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.read<NotificationViewModel>().resetStatus();
      });
    }

    if (vm.status == NotifSaveStatus.error && vm.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.error!), backgroundColor: AppColors.danger),
        );
        context.read<NotificationViewModel>().resetStatus();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Notificações',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: vm.loading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.accent))
          : _NotificationBody(vm: vm),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _NotificationBody extends StatelessWidget {
  final NotificationViewModel vm;
  const _NotificationBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cfg = vm.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          _Header(),
          const SizedBox(height: 24),

          // ── Toggle principal ────────────────────────────────────────────────
          _Card(
            child: Row(children: [
              const Icon(Icons.notifications_active_outlined,
                  color: AppColors.accent, size: 22),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ativar notificações',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('Receber alertas de vencimento',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ]),
              ),
              Switch(
                value: cfg.ativado,
                onChanged: vm.setAtivado,
                activeThumbColor: AppColors.accent,
                inactiveTrackColor: Colors.white12,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Opções (desabilitadas se inativo) ──────────────────────────────
          AnimatedOpacity(
            opacity: cfg.ativado ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !cfg.ativado,
              child: Column(children: [

                // ── Dias antes ─────────────────────────────────────────────
                _Card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RowLabel(
                          icon:  Icons.calendar_today_outlined,
                          label: 'Avisar quantos dias antes?',
                          value: '${cfg.diasAntes} dia${cfg.diasAntes > 1 ? 's' : ''}',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: NotificationConfig.opDiasAntes
                              .map((d) => _Chip(
                            label:    '$d d',
                            selected: cfg.diasAntes == d,
                            onTap:    () => vm.setDiasAntes(d),
                          ))
                              .toList(),
                        ),
                      ]),
                ),
                const SizedBox(height: 12),

                // ── Horário ────────────────────────────────────────────────
                _Card(
                  child: _RowLabel(
                    icon:  Icons.access_time_outlined,
                    label: 'Horário da notificação',
                    value: cfg.horarioLabel,
                    trailing: _TextButton(
                      label: 'Alterar',
                      onTap: () => _pickTime(context, vm, cfg),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Intervalo de repetição ─────────────────────────────────
                _Card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RowLabel(
                          icon:  Icons.repeat_outlined,
                          label: 'Repetir a cada',
                          value: cfg.intervaloLabel,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: NotificationConfig.opIntervaloHoras
                              .map((h) => _Chip(
                            label:    _intervaloShort(h),
                            selected: cfg.intervaloHoras == h,
                            onTap:    () => vm.setIntervalo(h),
                          ))
                              .toList(),
                        ),
                      ]),
                ),
                const SizedBox(height: 12),

                // ── Preview ────────────────────────────────────────────────
                _PreviewCard(config: cfg),
                const SizedBox(height: 20),

                // ── Botão testar ───────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: () => vm.testar(),
                  icon: const Icon(Icons.send_outlined,
                      color: AppColors.accent, size: 18),
                  label: const Text('Enviar notificação de teste',
                      style: TextStyle(color: AppColors.accent, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),

          // ── Botão salvar ────────────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: vm.isSaving ? null : () => vm.salvar(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor:
                AppColors.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: vm.isSaving
                  ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : const Text('Salvar e agendar',
                  style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(
      BuildContext context,
      NotificationViewModel vm,
      NotificationConfig cfg,
      ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cfg.hora, minute: cfg.minuto),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
              primary: AppColors.accent, surface: AppColors.surface),
          timePickerTheme: const TimePickerThemeData(
            backgroundColor:    AppColors.surface,
            hourMinuteColor:    AppColors.bg,
            hourMinuteTextColor: Colors.white,
            dialBackgroundColor: AppColors.bg,
            dialHandColor:      AppColors.accent,
            dialTextColor:      Colors.white,
            entryModeIconColor: AppColors.accent,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) vm.setHorario(picked.hour, picked.minute);
  }

  String _intervaloShort(int h) {
    switch (h) {
      case 24:  return 'Diário';
      case 48:  return '2 dias';
      case 72:  return '3 dias';
      case 168: return 'Semanal';
      default:  return '${h}h';
    }
  }
}

// ─── Widgets privados ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.notifications_outlined,
            color: Colors.white, size: 24),
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Alertas de validade',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Receba avisos antes que seus produtos vençam.',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10)),
    child: child,
  );
}

class _RowLabel extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Widget?  trailing;

  const _RowLabel({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.white54, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

class _TextButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _TextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.2) : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.white24,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      selected ? AppColors.accent : Colors.white60,
            fontSize:   13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final NotificationConfig config;
  const _PreviewCard({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.preview_outlined, color: AppColors.accent, size: 16),
          SizedBox(width: 8),
          Text('Como vai funcionar',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        _line(
          '• Primeiro aviso ${config.diasAntes} '
              'dia${config.diasAntes > 1 ? 's' : ''} antes do vencimento, '
              'às ${config.horarioLabel}',
        ),
        const SizedBox(height: 4),
        _line(
          '• Repetido ${config.intervaloLabel.toLowerCase()} '
              'até a data de validade',
        ),
        const SizedBox(height: 4),
        _line('• Máximo de 20 notificações por produto'),
      ]),
    );
  }

  Widget _line(String text) => Text(
    text,
    style: const TextStyle(
        color: Colors.white70, fontSize: 12, height: 1.5),
  );
}
