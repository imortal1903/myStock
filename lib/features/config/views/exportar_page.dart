import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/color_palette.dart';
import '../services/relatorio_service.dart';
import '../viewmodels/exportar_viewmodel.dart';

/// Cor de texto sobre fundo `accent` (mesma usada nos chips de
/// VendaConfigPage).
const _kTextoSobreAccent = Color(0xFF1A1A2E);

class ExportarPage extends StatelessWidget {
  const ExportarPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => ExportarViewModel(),
    child: const _ExportarView(),
  );
}

class _ExportarView extends StatelessWidget {
  const _ExportarView();

  static IconData _icone(ModeloRelatorio m) {
    switch (m) {
      case ModeloRelatorio.posicaoEstoque:
        return Icons.inventory_2_outlined;
      case ModeloRelatorio.validadePerdas:
        return Icons.event_busy_outlined;
      case ModeloRelatorio.vendasPorPeriodo:
        return Icons.receipt_long_outlined;
      case ModeloRelatorio.maisMenosVendidos:
        return Icons.leaderboard_outlined;
      case ModeloRelatorio.reposicaoSugerida:
        return Icons.add_shopping_cart_outlined;
      case ModeloRelatorio.movimentacoesEstoque:
        return Icons.swap_vert_rounded;
    }
  }

  Future<void> _escolherPeriodo(
      BuildContext context,
      ExportarViewModel vm,
      PeriodoPreset p,
      ) async {
    if (p != PeriodoPreset.personalizado) {
      vm.definirPreset(p);
      return;
    }

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final inicial = vm.customDesde != null && vm.customAte != null
        ? DateTimeRange(start: vm.customDesde!, end: vm.customAte!)
        : DateTimeRange(
        start: DateTime(hoje.year, hoje.month, hoje.day - 29), end: hoje);

    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: hoje,
      initialDateRange: inicial,
      helpText: 'Escolha o período',
      saveText: 'Aplicar',
    );
    if (r != null) vm.definirPeriodoPersonalizado(r.start, r.end);
  }

  Future<void> _acao(BuildContext context, AcaoExportacao acao) async {
    final vm = context.read<ExportarViewModel>();
    final r = await vm.exportar(acao);
    if (!context.mounted || r.mensagem == null) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(r.mensagem!)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<ExportarViewModel>();

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
        title: Text('Exportar relatório',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _Titulo('Modelos',
              badge: vm.modelo == null ? 'Personalizado' : null),
          const SizedBox(height: 10),
          for (final m in ModeloRelatorio.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ModeloCard(
                modelo: m,
                icone: _icone(m),
                selecionado: vm.modelo == m,
                onTap: () => vm.selecionarModelo(m),
              ),
            ),
          const SizedBox(height: 20),
          const _Titulo('O que incluir'),
          const SizedBox(height: 4),
          Text('Marque as tabelas e escolha as informações de cada uma.',
              style: TextStyle(color: colors.textFaint, fontSize: 12.5)),
          const SizedBox(height: 10),
          for (final s in SecaoRelatorio.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SecaoCard(secao: s),
            ),
          if (vm.usaPeriodo) ...[
            const SizedBox(height: 12),
            const _Titulo('Período'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in PeriodoPreset.values)
                _OpcaoChip(
                  label: p.label,
                  selecionado: vm.preset == p,
                  onTap: () => _escolherPeriodo(context, vm, p),
                ),
            ]),
            const SizedBox(height: 8),
            Text(vm.periodo.rotulo,
                style: TextStyle(color: colors.textFaint, fontSize: 12)),
          ],
          if (vm.usaValidade) ...[
            const SizedBox(height: 20),
            const _Titulo('Validade: vencidos e a vencer em até'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in const [7, 15, 30])
                _OpcaoChip(
                  label: '$d dias',
                  selecionado: vm.diasValidade == d,
                  onTap: () => vm.definirDiasValidade(d),
                ),
            ]),
          ],
          if (vm.usaCobertura) ...[
            const SizedBox(height: 20),
            const _Titulo('Reposição: cobrir as vendas de'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in const [7, 14, 30])
                _OpcaoChip(
                  label: '$d dias',
                  selecionado: vm.diasCobertura == d,
                  onTap: () => vm.definirDiasCobertura(d),
                ),
            ]),
          ],
          const SizedBox(height: 20),
          const _Titulo('Formato'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _OpcaoChip(
              label: 'CSV (planilha)',
              selecionado: vm.formato == FormatoExportacao.csv,
              onTap: () => vm.definirFormato(FormatoExportacao.csv),
            ),
            _OpcaoChip(
              label: 'PDF',
              selecionado: vm.formato == FormatoExportacao.pdf,
              onTap: () => vm.definirFormato(FormatoExportacao.pdf),
            ),
          ]),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: vm.temSelecao && !vm.exportando
                    ? () => _acao(context, AcaoExportacao.compartilhar)
                    : null,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Compartilhar'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: vm.temSelecao && !vm.exportando
                    ? () => _acao(context, AcaoExportacao.salvar)
                    : null,
                icon: vm.exportando
                    ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kTextoSobreAccent))
                    : const Icon(Icons.save_alt_outlined, size: 18),
                label: Text(vm.exportando ? 'Gerando...' : 'Salvar'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: _kTextoSobreAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Componentes
class _Titulo extends StatelessWidget {
  final String texto;
  final String? badge;
  const _Titulo(this.texto, {this.badge});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(children: [
      Expanded(
        child: Text(texto,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
      ),
      if (badge != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(badge!,
              style: TextStyle(
                color: colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
        ),
    ]);
  }
}

class _ModeloCard extends StatelessWidget {
  final ModeloRelatorio modelo;
  final IconData icone;
  final bool selecionado;
  final VoidCallback onTap;
  const _ModeloCard({
    required this.modelo,
    required this.icone,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selecionado
              ? colors.accent.withValues(alpha: 0.12)
              : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado ? colors.accent : colors.divider,
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selecionado ? colors.accent : colors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone,
                size: 20,
                color: selecionado ? _kTextoSobreAccent : colors.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(modelo.titulo,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 3),
                Text(modelo.oQueMostra,
                    style: TextStyle(
                      color: colors.textFaint,
                      fontSize: 12,
                      height: 1.35,
                    )),
                const SizedBox(height: 4),
                Text('Serve para: ${modelo.paraQueServe}',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Uma tabela do relatório: checkbox da tabela e, quando marcada, os chips
/// das informações (colunas) que dá pra incluir ou tirar.
class _SecaoCard extends StatelessWidget {
  final SecaoRelatorio secao;
  const _SecaoCard({required this.secao});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<ExportarViewModel>();
    final marcada = vm.secaoMarcada(secao);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: marcada ? colors.accent : colors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => vm.alternarSecao(secao),
          child: Row(children: [
            Checkbox(
              value: marcada,
              onChanged: (_) => vm.alternarSecao(secao),
              activeColor: colors.accent,
              checkColor: _kTextoSobreAccent,
              side: BorderSide(color: colors.textFaint, width: 1.5),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(secao.titulo,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text(secao.descricao,
                        style: TextStyle(
                          color: colors.textFaint,
                          fontSize: 12,
                          height: 1.3,
                        )),
                  ],
                ),
              ),
            ),
          ]),
        ),
        if (marcada)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 0, 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in secao.colunas)
                _OpcaoChip(
                  label: c.titulo,
                  selecionado: vm.colunaMarcada(secao, c.id),
                  fundo: colors.bg,
                  compacto: true,
                  onTap: () => vm.alternarColuna(secao, c.id),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _OpcaoChip extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;
  final Color? fundo;
  final bool compacto;
  const _OpcaoChip({
    required this.label,
    required this.selecionado,
    required this.onTap,
    this.fundo,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: compacto ? 10 : 14, vertical: compacto ? 7 : 10),
        decoration: BoxDecoration(
          color: selecionado ? colors.accent : (fundo ?? colors.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selecionado ? colors.accent : colors.divider),
        ),
        child: Text(label,
            style: TextStyle(
              color: selecionado ? _kTextoSobreAccent : colors.textSecondary,
              fontSize: compacto ? 12 : 13,
              fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}