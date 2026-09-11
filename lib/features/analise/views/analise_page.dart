import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/analise_viewmodel.dart';
import '../../crud/models/lote_com_produto.dart';
import '../../crud/models/movimentacao_estoque.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class AnalisePage extends StatelessWidget {
  const AnalisePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnaliseViewModel>();
    final carregandoPrimeiraVez = vm.status == ViewStatus.loading && vm.resumo == null;

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(children: [
          const _AnaliseTopBar(),
          Expanded(
            child: carregandoPrimeiraVez
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: vm.carregar,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _PeriodoSelector(vm: vm),
                    const SizedBox(height: 16),
                    if (vm.errorMessage != null) ...[
                      _ErrorBanner(mensagem: vm.errorMessage!),
                      const SizedBox(height: 16),
                    ],
                    if (vm.resumo != null) _ResumoCards(resumo: vm.resumo!),
                    const SizedBox(height: 20),
                    if (vm.resumoPorMotivo.isNotEmpty)
                      _MotivoChart(dados: vm.resumoPorMotivo),
                    const SizedBox(height: 20),
                    if (vm.lotesEmAtencao.isNotEmpty)
                      _AtencaoSection(lotes: vm.lotesEmAtencao),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────

class _AnaliseTopBar extends StatelessWidget {
  const _AnaliseTopBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(alignment: Alignment.center, children: [
        // Mesmo padrão de centralização usado em Estoque e Vendas: o título
        // fica travado no centro da tela, não no centro do espaço sobrando.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 96),
          child: Text('Análise',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              strutStyle: const StrutStyle(height: 1, forceStrutHeight: true),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              )),
        ),
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: colors.primary, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.analytics_outlined,
                color: colors.onPrimary, size: 20),
          ),
          const Spacer(),
          // Espaço reservado do mesmo tamanho de um IconButton real (48x48),
          // para a Row ter exatamente a mesma altura de referência que
          // Estoque e Vendas têm por causa dos ícones do lado direito.
          IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Seletor de período ───────────────────────────────────────────────────

class _PeriodoSelector extends StatelessWidget {
  final AnaliseViewModel vm;
  const _PeriodoSelector({required this.vm});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: PeriodoAnalise.values.map((p) {
      final selecionado = vm.periodo == p;
      return GestureDetector(
        onTap: () => vm.selecionarPeriodo(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selecionado ? context.colors.accent : context.colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selecionado ? context.colors.accent : context.colors.divider),
          ),
          child: Text(p.label,
              style: TextStyle(
                color: selecionado
                    ? const Color(0xFF1A1A2E)
                    : context.colors.textSecondary,
                fontSize: 12,
                fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
              )),
        ),
      );
    }).toList(),
  );
}

// ─── Cards de resumo ─────────────────────────────────────────────────────

class _ResumoCards extends StatelessWidget {
  final ResumoSaidas resumo;
  const _ResumoCards({required this.resumo});

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(
        child: _MetricCard(
          label: 'Vendidas',
          valor: '${resumo.quantidadeVendida} un',
          variacaoPct: resumo.variacaoQuantidadePct,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _MetricCard(
          label: 'Faturamento',
          valor:
          'R\$ ${resumo.faturamento.toStringAsFixed(2).replaceAll('.', ',')}',
          variacaoPct: resumo.variacaoFaturamentoPct,
        ),
      ),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(
        child: _MetricCard(
          label: 'Vencidas',
          valor: '${resumo.quantidadeVencida} un',
          destaque: resumo.quantidadeVencida > 0,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _MetricCard(
          label: 'Perdidas',
          valor:
          'R\$ ${resumo.valorPerdido.toStringAsFixed(2).replaceAll('.', ',')}',
          destaque: resumo.valorPerdido > 0,
        ),
      ),
    ]),
  ]);
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String valor;
  final double? variacaoPct;
  final bool destaque;
  const _MetricCard({
    required this.label,
    required this.valor,
    this.variacaoPct,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final corVariacao = variacaoPct == null
        ? null
        : (variacaoPct! >= 0 ? context.colors.success : context.colors.danger);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: destaque
            ? context.colors.danger.withValues(alpha: 0.08)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: destaque
            ? Border.all(color: context.colors.danger.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: context.colors.textFaint, fontSize: 12)),
        const SizedBox(height: 6),
        Text(valor,
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        if (variacaoPct != null) ...[
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              variacaoPct! >= 0
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: corVariacao,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text('${variacaoPct!.abs().toStringAsFixed(0)}%',
                style: TextStyle(
                    color: corVariacao, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }
}

// ─── Gráfico "para onde o estoque está indo" ────────────────────────────

class _MotivoChart extends StatelessWidget {
  final Map<String, int> dados;
  const _MotivoChart({required this.dados});

  String _labelPara(String chave) {
    final motivo = MotivoMovimentacaoExt.fromString(chave);
    if (motivo != null) return motivo.label;
    try {
      return TipoMovimentacaoExt.fromString(chave).label;
    } catch (_) {
      return chave;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entradas = dados.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maior = entradas.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Para onde o estoque está indo',
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        ...entradas.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MotivoBar(
            label: _labelPara(e.key),
            valor: e.value,
            proporcao: maior == 0 ? 0 : e.value / maior,
          ),
        )),
      ]),
    );
  }
}

class _MotivoBar extends StatelessWidget {
  final String label;
  final int valor;
  final double proporcao;
  const _MotivoBar({
    required this.label,
    required this.valor,
    required this.proporcao,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          Text('$valor un',
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: proporcao.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: context.colors.divider,
            valueColor: AlwaysStoppedAnimation(context.colors.accent),
          ),
        ),
      ]);
}

// ─── Seção Atenção ────────────────────────────────────────────────────────

class _AtencaoSection extends StatelessWidget {
  final List<LoteComProduto> lotes;
  const _AtencaoSection({required this.lotes});

  static String _prazoTexto(int dias) {
    if (dias <= 0) return 'vencem hoje';
    if (dias == 1) return 'vencem amanhã';
    return 'vencem em $dias dias';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.colors.danger.withValues(alpha: 0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.warning_amber_rounded, color: context.colors.danger, size: 20),
        const SizedBox(width: 8),
        Text('Atenção',
            style: TextStyle(
                color: context.colors.danger, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      ...lotes.map((item) {
        final l = item.lote;
        final numeroLote = l.numeroLote != null && l.numeroLote!.isNotEmpty
            ? ' · lote ${l.numeroLote}'
            : '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 13, height: 1.4),
              children: [
                TextSpan(
                  text: item.produtoNome,
                  style: TextStyle(
                      color: context.colors.textPrimary, fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: ' · ${l.quantidade} ${item.produtoUnidade} '
                      '${_prazoTexto(l.diasParaVencer)}$numeroLote',
                ),
              ],
            ),
          ),
        );
      }),
    ]),
  );
}

// ─── Erro ─────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String mensagem;
  const _ErrorBanner({required this.mensagem});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.colors.danger.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(mensagem,
        style: TextStyle(color: context.colors.danger, fontSize: 13)),
  );
}