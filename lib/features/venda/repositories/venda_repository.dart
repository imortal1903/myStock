import '../../../core/database/db.dart';
import '../../../core/extensions/quantidade_extensions.dart';
import '../../crud/models/movimentacao_estoque.dart';
import '../models/venda.dart';
import '../models/venda_item.dart';
import '../models/item_carrinho.dart';

class EstoqueInsuficienteException implements Exception {
  final String produtoNome;
  final double disponivel;
  final double solicitado;
  EstoqueInsuficienteException(this.produtoNome, this.disponivel, this.solicitado);

  @override
  String toString() =>
      'Estoque insuficiente para "$produtoNome": disponível ${disponivel.formatada}, solicitado ${solicitado.formatada}';
}

/// Quanto de um lote específico foi vendido numa semana específica - usado
/// para detalhar uma barra do gráfico de histórico em ProdutoAnalisePage.
class VendaLoteSemana {
  final int loteId;
  final String? numeroLote;
  final double quantidade;

  const VendaLoteSemana({
    required this.loteId,
    required this.numeroLote,
    required this.quantidade,
  });
}

/// Um item de venda já com o nome do produto e o lucro calculado - para a
/// tela de registro/histórico de vendas.
class VendaItemDetalhado {
  final int produtoId;
  final String produtoNome;
  final int loteId;
  final double quantidade;
  final double precoUnitario;
  final double subtotal;
  final double precoCustoAtual;

  const VendaItemDetalhado({
    required this.produtoId,
    required this.produtoNome,
    required this.loteId,
    required this.quantidade,
    required this.precoUnitario,
    required this.subtotal,
    required this.precoCustoAtual,
  });

  double get lucro => subtotal - (quantidade * precoCustoAtual);

  String get precoUnitarioFormatado =>
      'R\$ ${precoUnitario.toStringAsFixed(2).replaceAll('.', ',')}';

  String get subtotalFormatado =>
      'R\$ ${subtotal.toStringAsFixed(2).replaceAll('.', ',')}';

  String get lucroFormatado {
    final sinal = lucro < 0 ? '-' : '';
    return '$sinal R\$ ${lucro.abs().toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

/// Uma venda com seus itens detalhados - base da tela de registro de
/// vendas (código da venda, produtos, lucro por produto, lucro total e
/// faturamento).
class VendaDetalhada {
  final Venda venda;
  final List<VendaItemDetalhado> itens;

  const VendaDetalhada({required this.venda, required this.itens});

  double get lucroTotal => itens.fold(0, (acc, i) => acc + i.lucro);

  String get lucroTotalFormatado {
    final sinal = lucroTotal < 0 ? '-' : '';
    return '$sinal R\$ ${lucroTotal.abs().toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

class VendaRepository {
  final Db _db;
  VendaRepository({Db? db}) : _db = db ?? Db.instance;
  Future<int> finalizarVenda(List<ItemCarrinho> carrinho) async {
    if (carrinho.isEmpty) {
      throw ArgumentError('O carrinho está vazio.');
    }

    final db = await _db.database;
    final valorTotal = carrinho.fold<double>(0, (acc, i) => acc + i.subtotal);

    return db.transaction<int>((txn) async {
      final vendaId = await txn.insert('vendas', {'valor_total': valorTotal});

      for (final item in carrinho) {
        final loteRows = await txn.query(
          'lotes_produto',
          where: 'id = ?',
          whereArgs: [item.lote.id],
          limit: 1,
        );

        if (loteRows.isEmpty) {
          throw EstoqueInsuficienteException(item.produto.nome, 0, item.quantidade);
        }

        final disponivel = (loteRows.first['quantidade'] as num).toDouble();
        if (disponivel < item.quantidade) {
          throw EstoqueInsuficienteException(item.produto.nome, disponivel, item.quantidade);
        }

        final novaQuantidade = (disponivel - item.quantidade).arredondada;

        await txn.update(
          'lotes_produto',
          {
            'quantidade': novaQuantidade,
            'status': novaQuantidade <= 0.0009 ? 'ESGOTADO' : loteRows.first['status'],
          },
          where: 'id = ?',
          whereArgs: [item.lote.id],
        );

        await txn.insert('venda_itens', {
          'venda_id': vendaId,
          'produto_id': item.produto.id,
          'lote_id': item.lote.id,
          'quantidade': item.quantidade,
          'preco_unitario': item.precoUnitario,
          'subtotal': item.subtotal,
        });

        await txn.insert('movimentacoes_estoque', {
          'lote_id': item.lote.id,
          'tipo': 'SAIDA',
          'motivo': MotivoMovimentacao.venda.value,
          'quantidade': item.quantidade,
          'observacao': 'Venda #$vendaId',
        });
      }

      return vendaId;
    });
  }

  Future<List<Venda>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('vendas', orderBy: 'criado_em DESC');
    return rows.map(Venda.fromMap).toList();
  }

  Future<List<VendaItem>> getItensByVenda(int vendaId) async {
    final db = await _db.database;
    final rows = await db.query('venda_itens', where: 'venda_id = ?', whereArgs: [vendaId]);
    return rows.map(VendaItem.fromMap).toList();
  }

  Future<Map<String, dynamic>> getResumoDoDia() async {
    final db = await _db.database;
    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();

    final res = await db.rawQuery('''
      SELECT COUNT(*) as qtd_vendas, COALESCE(SUM(valor_total), 0) as total
      FROM vendas
      WHERE criado_em >= ?
    ''', [inicioDia]);

    return {
      'qtdVendas': res.first['qtd_vendas'] as int,
      'total': (res.first['total'] as num).toDouble(),
    };
  }

  /// Quantidade vendida por semana do produto [produtoId], das últimas
  /// [semanas] semanas corridas (índice 0 = semana mais recente),
  /// zero-preenchida para semanas sem venda.
  Future<List<double>> getVendasPorSemana(int produtoId, {int semanas = 12}) async {
    final db = await _db.database;
    final desde = DateTime.now().subtract(Duration(days: semanas * 7));

    final rows = await db.rawQuery('''
      SELECT
        CAST((julianday('now') - julianday(v.criado_em)) / 7 AS INTEGER) AS semanas_atras,
        SUM(vi.quantidade) AS total
      FROM venda_itens vi
      JOIN vendas v ON v.id = vi.venda_id
      WHERE vi.produto_id = ?
        AND v.criado_em >= ?
      GROUP BY semanas_atras
    ''', [produtoId, desde.toIso8601String()]);

    final porSemana = <int, double>{
      for (final r in rows)
        r['semanas_atras'] as int: (r['total'] as num).toDouble(),
    };

    return List.generate(semanas, (i) => porSemana[i] ?? 0.0);
  }

  /// Quanto de cada lote foi vendido numa semana específica de
  /// [produtoId]. [semanasAtras] usa a MESMA convenção de
  /// [getVendasPorSemana]: 0 = semana atual, 1 = semana passada, etc.
  Future<List<VendaLoteSemana>> getVendasPorLoteNaSemana(
      int produtoId, {
        required int semanasAtras,
      }) async {
    final db = await _db.database;

    final rows = await db.rawQuery('''
      SELECT
        vi.lote_id,
        lp.numero_lote,
        SUM(vi.quantidade) AS total
      FROM venda_itens vi
      JOIN vendas v ON v.id = vi.venda_id
      JOIN lotes_produto lp ON lp.id = vi.lote_id
      WHERE vi.produto_id = ?
        AND CAST((julianday('now') - julianday(v.criado_em)) / 7 AS INTEGER) = ?
      GROUP BY vi.lote_id, lp.numero_lote
      ORDER BY total DESC
    ''', [produtoId, semanasAtras]);

    return rows
        .map((r) => VendaLoteSemana(
      loteId: r['lote_id'] as int,
      numeroLote: r['numero_lote'] as String?,
      quantidade: (r['total'] as num).toDouble(),
    ))
        .toList();
  }

  /// Quantidade total vendida e faturamento no intervalo [desde, ate].
  /// Usado para montar os cards "Vendidas"/"Faturamento" e sua comparação
  /// com o período anterior de mesma duração.
  Future<Map<String, num>> getResumoPeriodo(DateTime desde, DateTime ate) async {
    final db = await _db.database;
    final res = await db.rawQuery('''
      SELECT
        COALESCE(SUM(vi.quantidade), 0) AS qtd,
        COALESCE(SUM(vi.subtotal), 0) AS faturamento
      FROM venda_itens vi
      JOIN vendas v ON v.id = vi.venda_id
      WHERE v.criado_em >= ? AND v.criado_em < ?
    ''', [desde.toIso8601String(), ate.toIso8601String()]);

    return {
      'qtd': (res.first['qtd'] as num).toDouble(),
      'faturamento': (res.first['faturamento'] as num).toDouble(),
    };
  }

  /// Todas as vendas com seus itens detalhados (nome do produto + lucro
  /// por item) — base da tela de registro de vendas.
  Future<List<VendaDetalhada>> getHistoricoDetalhado() async {
    final db = await _db.database;

    final vendasRows = await db.query('vendas', orderBy: 'criado_em DESC');
    if (vendasRows.isEmpty) return [];

    final vendaIds = vendasRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(vendaIds.length, '?').join(',');

    final itensRows = await db.rawQuery('''
      SELECT
        vi.venda_id,
        vi.produto_id,
        vi.lote_id,
        vi.quantidade,
        vi.preco_unitario,
        vi.subtotal,
        COALESCE(p.nome, 'Produto removido') AS produto_nome,
        COALESCE(lp.preco_custo, 0) AS preco_custo_atual
      FROM venda_itens vi
      LEFT JOIN produtos p ON p.id = vi.produto_id
      LEFT JOIN lotes_produto lp ON lp.id = vi.lote_id
      WHERE vi.venda_id IN ($placeholders)
      ORDER BY vi.id ASC
    ''', vendaIds);

    final itensPorVenda = <int, List<VendaItemDetalhado>>{};
    for (final r in itensRows) {
      final item = VendaItemDetalhado(
        produtoId: r['produto_id'] as int,
        produtoNome: r['produto_nome'] as String,
        loteId: r['lote_id'] as int,
        quantidade: (r['quantidade'] as num).toDouble(),
        precoUnitario: (r['preco_unitario'] as num).toDouble(),
        subtotal: (r['subtotal'] as num).toDouble(),
        precoCustoAtual: (r['preco_custo_atual'] as num).toDouble(),
      );
      itensPorVenda.putIfAbsent(r['venda_id'] as int, () => []).add(item);
    }

    return vendasRows.map((r) {
      final venda = Venda.fromMap(r);
      return VendaDetalhada(
        venda: venda,
        itens: itensPorVenda[venda.id] ?? [],
      );
    }).toList();
  }
}