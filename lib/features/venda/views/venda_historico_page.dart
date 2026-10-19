import 'package:flutter/material.dart';

import '../../../core/theme/color_palette.dart';
import '../../../core/extensions/quantidade_extensions.dart';
import '../../../core/widgets/app_search_field.dart';
import '../repositories/venda_repository.dart';

enum _Ordem {
  maisRecentes('Mais recentes'),
  maisAntigas('Mais antigas'),
  maiorFaturamento('Maior faturamento'),
  maiorLucro('Maior lucro');

  final String label;
  const _Ordem(this.label);
}

/// Registro de vendas: código da venda, produtos vendidos, lucro por
/// produto e total, e faturamento de cada venda.
class VendaHistoricoPage extends StatefulWidget {
  const VendaHistoricoPage({super.key});

  @override
  State<VendaHistoricoPage> createState() => _VendaHistoricoPageState();
}

class _VendaHistoricoPageState extends State<VendaHistoricoPage> {
  final _repo = VendaRepository();
  final _searchCtrl = TextEditingController();
  late Future<List<VendaDetalhada>> _future;

  List<VendaDetalhada> _todas = [];
  String _query = '';
  _Ordem _ordem = _Ordem.maisRecentes;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<VendaDetalhada>> _carregar() async {
    final vendas = await _repo.getHistoricoDetalhado();
    _todas = vendas;
    return vendas;
  }

  Future<void> _recarregar() async {
    final novo = _carregar();
    setState(() {
      _future = novo;
    });
    await novo;
  }

  List<VendaDetalhada> get _filtradas {
    final termo = _query.trim().toLowerCase();

    final lista = termo.isEmpty
        ? List<VendaDetalhada>.of(_todas)
        : _todas.where((v) {
      if (v.venda.id.toString().contains(termo)) return true;
      return v.itens
          .any((i) => i.produtoNome.toLowerCase().contains(termo));
    }).toList();

    lista.sort(_comparador);
    return lista;
  }

  int _porData(VendaDetalhada a, VendaDetalhada b) {
    final c = a.venda.criadoEm.compareTo(b.venda.criadoEm);
    return c != 0 ? c : (a.venda.id ?? 0).compareTo(b.venda.id ?? 0);
  }

  /// Nos critérios por valor, empate desempata pela venda mais recente
  int Function(VendaDetalhada, VendaDetalhada) get _comparador {
    switch (_ordem) {
      case _Ordem.maisRecentes:
        return (a, b) => _porData(b, a);
      case _Ordem.maisAntigas:
        return _porData;
      case _Ordem.maiorFaturamento:
        return (a, b) {
          final c = b.venda.valorTotal.compareTo(a.venda.valorTotal);
          return c != 0 ? c : _porData(b, a);
        };
      case _Ordem.maiorLucro:
        return (a, b) {
          final c = b.lucroTotal.compareTo(a.lucroTotal);
          return c != 0 ? c : _porData(b, a);
        };
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Registro de vendas',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        centerTitle: true,
      ),
      body: FutureBuilder<List<VendaDetalhada>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: colors.accent));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar as vendas.',
                  style: TextStyle(color: colors.danger)),
            );
          }

          if (_todas.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined,
                    color: colors.divider, size: 52),
                const SizedBox(height: 12),
                Text('Nenhuma venda registrada ainda.',
                    style: TextStyle(color: colors.textFaint, fontSize: 14)),
              ]),
            );
          }

          final vendas = _filtradas;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: AppSearchField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                hintText: 'Pesquisar por produto ou nº da venda...',
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                itemCount: _Ordem.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final o = _Ordem.values[i];
                  return _OrdemChip(
                    label: o.label,
                    selecionado: _ordem == o,
                    onTap: () => setState(() => _ordem = o),
                  );
                },
              ),
            ),
            Expanded(
              child: vendas.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Nenhuma venda encontrada para "${_query.trim()}".',
                    textAlign: TextAlign.center,
                    style:
                    TextStyle(color: colors.textFaint, fontSize: 14),
                  ),
                ),
              )
                  : RefreshIndicator(
                color: colors.accent,
                backgroundColor: colors.surface,
                onRefresh: _recarregar,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: vendas.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (_, i) => _VendaCard(venda: vendas[i]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}


class _OrdemChip extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;
  const _OrdemChip({
    required this.label,
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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selecionado ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selecionado ? colors.accent : colors.divider),
        ),
        child: Text(label,
            style: TextStyle(
              color: selecionado
                  ? const Color(0xFF1A1A2E)
                  : colors.textSecondary,
              fontSize: 13,
              fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}

class _VendaCard extends StatelessWidget {
  final VendaDetalhada venda;
  const _VendaCard({required this.venda});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lucroTotal = venda.lucroTotal;
    final corLucro = lucroTotal >= 0 ? colors.success : colors.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Venda #${venda.venda.id}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
          Text(venda.venda.dataFormatada,
              style: TextStyle(color: colors.textFaint, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        ...venda.itens.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.produtoNome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantidade.formatada} x '
                        '${item.precoUnitarioFormatado} = '
                        '${item.subtotalFormatado}',
                    style: TextStyle(color: colors.textFaint, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.lucroFormatado,
              style: TextStyle(
                color: item.lucro >= 0 ? colors.success : colors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        )),
        Divider(color: colors.divider, height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Faturamento',
                style: TextStyle(color: colors.textFaint, fontSize: 11)),
            Text(venda.venda.valorTotalFormatado,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                )),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Lucro total',
                style: TextStyle(color: colors.textFaint, fontSize: 11)),
            Text(venda.lucroTotalFormatado,
                style: TextStyle(
                  color: corLucro,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        ]),
      ]),
    );
  }
}