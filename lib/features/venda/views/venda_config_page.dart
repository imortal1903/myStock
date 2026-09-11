import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/color_palette.dart';
import '../viewmodels/venda_viewmodel.dart';

// ─── Página de configuração da recomendação de lotes ───────────────────────────

class VendaConfigPage extends StatelessWidget {
  const VendaConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(children: [
          const _TopBar(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _ExplicacaoCard(),
                const SizedBox(height: 20),
                Text('Ajustar prioridade',
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Arraste para o lado que for mais importante para o seu negócio.',
                    style: TextStyle(color: context.colors.textFaint, fontSize: 13)),
                const SizedBox(height: 16),
                const _PesoSliderCard(),
                const SizedBox(height: 20),
                Text('Atalhos rápidos',
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const _PresetChips(),
                const SizedBox(height: 20),
                const _ExemploCard(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

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
          child: Text('Recomendação de lotes',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        const SizedBox(width: 48), // balanceia o botão de voltar
      ]),
    );
  }
}

// ─── Card explicativo ───────────────────────────────────────────────────────────

class _ExplicacaoCard extends StatelessWidget {
  const _ExplicacaoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: context.colors.onPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.star_rounded, color: context.colors.onPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('O que é o lote "Recomendado"?',
                style: TextStyle(color: context.colors.onPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Ao vender, sugerimos automaticamente o melhor lote considerando dois fatores: '
                  'quão perto ele está de vencer e quão baixo está o estoque dele. '
                  'Aqui você decide qual desses fatores pesa mais na hora da sugestão.',
              style: TextStyle(color: context.colors.onPrimarySecondary, fontSize: 12.5, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Slider de ponderação ───────────────────────────────────────────────────────

class _PesoSliderCard extends StatelessWidget {
  const _PesoSliderCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendaViewModel>();
    final pctValidade = (vm.pesoValidade * 100).round();
    final pctEstoque  = 100 - pctValidade;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _PesoExtremo(
            icon: Icons.inventory_2_outlined,
            label: 'Estoque baixo',
            pct: pctEstoque,
            alignEnd: false,
          ),
          _PesoExtremo(
            icon: Icons.schedule_rounded,
            label: 'Validade próxima',
            pct: pctValidade,
            alignEnd: true,
          ),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: context.colors.accent,
            inactiveTrackColor: context.colors.divider,
            thumbColor: context.colors.accent,
            overlayColor: context.colors.accent.withValues(alpha: 0.15),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: vm.pesoValidade,
            onChanged: vm.atualizarPesoValidade,
          ),
        ),
        if (!vm.pesoEhPadrao)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: vm.restaurarPesoPadrao,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.replay_rounded, color: context.colors.accent, size: 14),
                const SizedBox(width: 4),
                Text('Restaurar padrão (65% validade · 35% estoque)',
                    style: TextStyle(color: context.colors.accent, fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _PesoExtremo extends StatelessWidget {
  final IconData icon;
  final String label;
  final int pct;
  final bool alignEnd;
  const _PesoExtremo({required this.icon, required this.label, required this.pct, required this.alignEnd});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: alignEnd
            ? [
          Text(label, style: TextStyle(color: context.colors.textFaint, fontSize: 11)),
          const SizedBox(width: 4),
          Icon(icon, color: context.colors.textFaint, size: 13),
        ]
            : [
          Icon(icon, color: context.colors.textFaint, size: 13),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: context.colors.textFaint, fontSize: 11)),
        ],
      ),
      const SizedBox(height: 2),
      Text('$pct%',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
    ],
  );
}

// ─── Atalhos rápidos (presets) ───────────────────────────────────────────────────

class _Preset {
  final String label;
  final double valor;
  const _Preset(this.label, this.valor);
}

const _presets = [
  _Preset('Só estoque', 0.0),
  _Preset('Focar estoque', 0.2),
  _Preset('Equilibrado', 0.5),
  _Preset('Padrão', kPesoValidadePadrao),
  _Preset('Focar validade', 0.9),
  _Preset('Só validade', 1.0),
];

class _PresetChips extends StatelessWidget {
  const _PresetChips();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendaViewModel>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presets.map((p) {
        final selecionado = (vm.pesoValidade - p.valor).abs() < 0.01;
        return GestureDetector(
          onTap: () => vm.atualizarPesoValidade(p.valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selecionado ? context.colors.accent : context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selecionado ? context.colors.accent : context.colors.divider),
            ),
            child: Text(p.label,
                style: TextStyle(
                  color: selecionado ? const Color(0xFF1A1A2E) : context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Exemplo dinâmico ───────────────────────────────────────────────────────────

class _ExemploCard extends StatelessWidget {
  const _ExemploCard();

  String _descricao(double pesoValidade) {
    if (pesoValidade >= 0.8) {
      return 'Vamos sugerir quase sempre o lote que vence primeiro, mesmo que ele tenha bastante estoque. '
          'Ideal para produtos perecíveis, onde perder um lote por validade custa mais caro.';
    }
    if (pesoValidade >= 0.6) {
      return 'Vamos priorizar o lote que vence primeiro, mas sem ignorar o estoque, nosso equilíbrio padrão. '
          'Bom para a maioria dos negócios.';
    }
    if (pesoValidade > 0.4) {
      return 'Validade e estoque terão praticamente o mesmo peso na sugestão.';
    }
    if (pesoValidade > 0.2) {
      return 'Vamos priorizar o lote com menos unidades no estoque, mas sem ignorar a validade. '
          'Útil para girar lotes pequenos que sobraram de compras antigas.';
    }
    return 'Vamos sugerir quase sempre o lote com menos unidades, mesmo que vença depois dos outros. '
        'Ideal para produtos não perecíveis, onde o que importa é esvaziar estoques pequenos primeiro.';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendaViewModel>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lightbulb_outline, color: context.colors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(_descricao(vm.pesoValidade),
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13, height: 1.5)),
        ),
      ]),
    );
  }
}