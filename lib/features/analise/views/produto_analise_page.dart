import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/produto_analise_viewmodel.dart';
import '../services/previsao_estoque_service.dart';
import '../../venda/repositories/venda_repository.dart' show VendaLoteSemana;
import '../../../core/extensions/quantidade_extensions.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/viewmodels/base_viewmodel.dart';

class ProdutoAnalisePage extends StatelessWidget {
  final int produtoId;
  final String produtoNome;
  final String produtoUnidade;

  const ProdutoAnalisePage({
    super.key,
    required this.produtoId,
    required this.produtoNome,
    required this.produtoUnidade,
  });

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => ProdutoAnaliseViewModel(produtoId: produtoId),
    child: _ProdutoAnaliseView(
      produtoNome: produtoNome,
      produtoUnidade: produtoUnidade,
    ),
  );
}

class _ProdutoAnaliseView extends StatelessWidget {
  final String produtoNome;
  final String produtoUnidade;
  const _ProdutoAnaliseView({
    required this.produtoNome,
    required this.produtoUnidade,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProdutoAnaliseViewModel>();
    final carregando = vm.status == ViewStatus.loading && vm.previsao == null;
    final colors = context.colors;

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
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Análise',
              style: TextStyle(
                  color: colors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          Text(produtoNome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ]),
        centerTitle: true,
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: vm.carregar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vm.errorMessage != null) ...[
                _ErrorBanner(mensagem: vm.errorMessage!),
                const SizedBox(height: 16),
              ],
              if (vm.previsao != null)
                _GiroCard(previsao: vm.previsao!, unidade: produtoUnidade),
              const SizedBox(height: 20),
              if (vm.historicoSemanal.isNotEmpty)
                _HistoricoChart(semanas: vm.historicoSemanal, unidade: produtoUnidade),
              const SizedBox(height: 20),
              if (vm.lotesEmRisco.isNotEmpty)
                _RiscoSection(lotes: vm.lotesEmRisco, unidade: produtoUnidade),
            ],
          ),
        ),
      ),
    );
  }
}

// Giro de estoque

class _GiroCard extends StatelessWidget {
  final PrevisaoEstoque previsao;
  final String unidade;
  const _GiroCard({required this.previsao, required this.unidade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: context.colors.primary, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Giro de estoque',
            style: TextStyle(
                color: context.colors.onPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _GiroBlock(
            label: 'Em estoque',
            value: '${previsao.estoqueAtual.formatada} $unidade',
          ),
          _GiroBlock(
            label: 'Média de saída',
            value: previsao.mediaSemanal != null
                ? '${previsao.mediaSemanal!.toStringAsFixed(1)} $unidade/sem.'
                : '—',
            alignEnd: true,
          ),
        ]),
        const SizedBox(height: 14),
        Divider(color: context.colors.onPrimaryMuted.withValues(alpha: 0.3), height: 1),
        const SizedBox(height: 14),
        if (previsao.semPrevisaoConfiavel)
          Row(children: [
            Icon(Icons.info_outline, color: context.colors.onPrimaryMuted, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                previsao.regra == RegraJanela.semDadosSuficientes
                    ? 'Sem histórico de vendas suficiente para estimar duração.'
                    : 'Movimentação baixa demais para uma estimativa confiável.',
                style: TextStyle(color: context.colors.onPrimaryMuted, fontSize: 12.5),
              ),
            ),
          ])
        else ...[
          Text('Previsão de duração',
              style: TextStyle(color: context.colors.onPrimaryMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text('~${previsao.semanasRestantes!.toStringAsFixed(1)} semanas',
              style: TextStyle(
                  color: context.colors.onPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(previsao.regra.descricao,
              style: TextStyle(color: context.colors.onPrimaryMuted, fontSize: 11.5)),
        ],
      ]),
    );
  }
}

class _GiroBlock extends StatelessWidget {
  final String label, value;
  final bool alignEnd;
  const _GiroBlock({required this.label, required this.value, this.alignEnd = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: context.colors.onPrimaryMuted, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              color: context.colors.onPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
    ],
  );
}

// Histórico semanal

class _HistoricoChart extends StatefulWidget {
  /// Índice 0 = semana mais recente.
  final List<double> semanas;
  final String unidade;
  const _HistoricoChart({required this.semanas, required this.unidade});

  @override
  State<_HistoricoChart> createState() => _HistoricoChartState();
}

class _HistoricoChartState extends State<_HistoricoChart> {
  /// "semanasAtras" da barra atualmente expandida (0 = semana atual), ou
  /// `null` se nenhuma estiver selecionada.
  int? _semanaSelecionada;

  String _labelSemana(int semanasAtras) {
    if (semanasAtras == 0) return 'Esta semana';
    if (semanasAtras == 1) return 'Semana passada';
    return 'Há $semanasAtras semanas';
  }

  void _alternarSelecao(int semanasAtras) {
    final vm = context.read<ProdutoAnaliseViewModel>();
    setState(() {
      _semanaSelecionada = _semanaSelecionada == semanasAtras ? null : semanasAtras;
    });
    if (_semanaSelecionada != null) vm.carregarDetalheSemana(semanasAtras);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProdutoAnaliseViewModel>();
    // Ordem cronológica para o gráfico: mais antiga primeiro.
    final cronologico = widget.semanas.reversed.toList();
    final maior = cronologico.isEmpty
        ? 0.0
        : cronologico.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vendas por semana',
            style: TextStyle(
                color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Últimas ${widget.semanas.length} semanas · toque numa barra para ver os lotes',
            style: TextStyle(color: context.colors.textFaint, fontSize: 12)),
        const SizedBox(height: 16),
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: cronologico.asMap().entries.map((entry) {
              final qtd = entry.value;
              // cronologico[0] é a semana mais antiga; a mais recente
              // (semanasAtras = 0) fica no fim da lista invertida.
              final semanasAtras = cronologico.length - 1 - entry.key;
              final selecionada = _semanaSelecionada == semanasAtras;
              final proporcao = maior == 0 ? 0.0 : qtd / maior;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _alternarSelecao(semanasAtras),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SizedBox(
                          height: 12,
                          child: qtd > 0
                              ? Text(qtd.formatada,
                              style: TextStyle(
                                  color: selecionada
                                      ? context.colors.accent
                                      : context.colors.textFaint,
                                  fontSize: 9,
                                  fontWeight:
                                  selecionada ? FontWeight.w700 : FontWeight.normal))
                              : null,
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: FractionallySizedBox(
                            heightFactor: proporcao.clamp(0.04, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: selecionada
                                    ? context.colors.accent
                                    : context.colors.accent.withValues(
                                  alpha: qtd == 0 ? 0.2 : 0.85,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: selecionada
                                    ? Border.all(color: context.colors.accent, width: 1.5)
                                    : null,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_semanaSelecionada != null) ...[
          const SizedBox(height: 14),
          Divider(color: context.colors.divider, height: 1),
          const SizedBox(height: 14),
          _DetalheSemana(
            label: _labelSemana(_semanaSelecionada!),
            unidade: widget.unidade,
            carregando: vm.carregandoDetalheSemana(_semanaSelecionada!),
            lotes: vm.detalhesPorSemana[_semanaSelecionada!],
          ),
        ],
      ]),
    );
  }
}

class _DetalheSemana extends StatelessWidget {
  final String label;
  final String unidade;
  final bool carregando;
  final List<VendaLoteSemana>? lotes;

  const _DetalheSemana({
    required this.label,
    required this.unidade,
    required this.carregando,
    required this.lotes,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      if (carregando)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        )
      else if (lotes == null || lotes!.isEmpty)
        Text('Nenhuma venda registrada nessa semana.',
            style: TextStyle(color: colors.textFaint, fontSize: 13))
      else
        ...lotes!.map((l) {
          final nomeLote = (l.numeroLote?.trim().isNotEmpty ?? false)
              ? 'Lote ${l.numeroLote}'
              : 'Sem número';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(nomeLote,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              ),
              Text('${l.quantidade.formatada} $unidade',
                  style: TextStyle(
                      color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          );
        }),
    ]);
  }
}

class _RiscoSection extends StatelessWidget {
  final List<LoteEmRisco> lotes;
  final String unidade;
  const _RiscoSection({required this.lotes, required this.unidade});

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
        Expanded(
          child: Text('Risco de vencimento',
              style: TextStyle(
                  color: context.colors.danger, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 4),
      Text(
        'Estimativa considerando a ordem de validade dos lotes.',
        style: TextStyle(color: context.colors.textFaint, fontSize: 11.5, height: 1.4),
      ),
      const SizedBox(height: 12),
      ...lotes.map((r) {
        final l = r.lote;
        final numeroLote =
        l.numeroLote != null && l.numeroLote!.isNotEmpty ? ' · lote ${l.numeroLote}' : '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${r.quantidadeEmRisco.formatada} $unidade em risco de ${l.quantidade.formatada} '
                'no total$numeroLote · vence em ${l.diasParaVencer} '
                '${l.diasParaVencer == 1 ? 'dia' : 'dias'}',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13, height: 1.4),
          ),
        );
      }),
    ]),
  );
}

// Erro

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
    child: Text(mensagem, style: TextStyle(color: context.colors.danger, fontSize: 13)),
  );
}