import '../../../core/database/db.dart';
import '../models/venda.dart';
import '../models/venda_item.dart';
import '../models/item_carrinho.dart';

class EstoqueInsuficienteException implements Exception {
  final String produtoNome;
  final int disponivel;
  final int solicitado;
  EstoqueInsuficienteException(this.produtoNome, this.disponivel, this.solicitado);

  @override
  String toString() =>
      'Estoque insuficiente para "$produtoNome": disponível $disponivel, solicitado $solicitado';
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

        final disponivel = loteRows.first['quantidade'] as int;
        if (disponivel < item.quantidade) {
          throw EstoqueInsuficienteException(item.produto.nome, disponivel, item.quantidade);
        }

        final novaQuantidade = disponivel - item.quantidade;

        await txn.update(
          'lotes_produto',
          {
            'quantidade': novaQuantidade,
            'status': novaQuantidade == 0 ? 'ESGOTADO' : loteRows.first['status'],
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
}