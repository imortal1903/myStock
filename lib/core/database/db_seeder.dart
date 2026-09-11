import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'db.dart';

class DbSeeder {
  static Future<void> popularBanco() async {
    final db = await Db.instance.database;
    final batch = db.batch();

    // 1. Limpar dados existentes (Opcional - remova se quiser apenas somar)
    batch.execute('DELETE FROM venda_itens');
    batch.execute('DELETE FROM vendas');
    batch.execute('DELETE FROM movimentacoes_estoque');
    batch.execute('DELETE FROM lotes_produto');
    batch.execute('DELETE FROM produtos');
    batch.execute('DELETE FROM categorias');
    batch.execute('DELETE FROM notificacoes');

    // 2. Categorias
    final categorias = ['Alimentos', 'Bebidas', 'Limpeza', 'Higiene', 'Hortifruti'];
    for (var cat in categorias) {
      batch.insert('categorias', {'nome': cat, 'criado_em': _format(DateTime.now().subtract(const Duration(days: 370)))});
    }
    await batch.commit(noResult: true);

    // 3. Produtos
    final prodData = [
      {'nome': 'Arroz 5kg', 'cat': 1, 'un': 'UN', 'min': 10},
      {'nome': 'Feijão Preto 1kg', 'cat': 1, 'un': 'UN', 'min': 15},
      {'nome': 'Coca-Cola 2L', 'cat': 2, 'un': 'UN', 'min': 20},
      {'nome': 'Detergente Neutro', 'cat': 3, 'un': 'UN', 'min': 30},
      {'nome': 'Sabonete 90g', 'cat': 4, 'un': 'UN', 'min': 50},
      {'nome': 'Tomate', 'cat': 5, 'un': 'KG', 'min': 5},
    ];

    for (var p in prodData) {
      db.insert('produtos', {
        'nome': p['nome'],
        'categoria_id': p['cat'],
        'unidade': p['un'],
        'estoque_min': p['min'],
        'ativo': 1,
        'criado_em': _format(DateTime.now().subtract(const Duration(days: 368)))
      });
    }

    final random = Random();
    final hoje = DateTime.now();
    final inicio = hoje.subtract(const Duration(days: 365));

    // 4. Simulação de 365 dias
    for (int i = 0; i <= 365; i++) {
      final dataAtual = inicio.add(Duration(days: i));
      final dataStr = _format(dataAtual);

      // A cada 15 dias, entra um novo lote de cada produto
      if (i % 15 == 0) {
        final produtos = await db.query('produtos');
        for (var prod in produtos) {
          final precoCusto = 5.0 + random.nextDouble() * 20;
          final precoVenda = precoCusto * 1.4;
          final qtd = 20.0 + random.nextInt(50);
          
          final loteId = await db.insert('lotes_produto', {
            'produto_id': prod['id'],
            'numero_lote': 'L${dataAtual.millisecondsSinceEpoch}',
            'quantidade': qtd,
            'quantidade_inicial': qtd,
            'preco_custo': precoCusto,
            'preco_venda': precoVenda,
            'data_fabricacao': _format(dataAtual.subtract(const Duration(days: 5))),
            'data_validade': _format(dataAtual.add(Duration(days: 30 + random.nextInt(180)))),
            'data_entrada': dataStr,
            'status': 'ATIVO',
            'criado_em': dataStr,
          });

          await db.insert('movimentacoes_estoque', {
            'lote_id': loteId,
            'tipo': 'ENTRADA',
            'motivo': 'COMPRA_FORNECEDOR',
            'quantidade': qtd,
            'criado_em': dataStr,
          });
        }
      }

      // Vendas Diárias (entre 2 e 8 vendas por dia)
      final qtdVendas = 2 + random.nextInt(6);
      for (int v = 0; v < qtdVendas; v++) {
        final lotesDisponiveis = await db.rawQuery(
          "SELECT * FROM lotes_produto WHERE quantidade > 0 AND status = 'ATIVO' AND data_validade > ?",
          [dataStr]
        );

        if (lotesDisponiveis.isEmpty) continue;

        // Seleciona 1 a 3 itens aleatórios para a venda
        final itensParaVender = (random.nextInt(3) + 1);
        double totalVenda = 0;
        final vendaId = await db.insert('vendas', {'valor_total': 0, 'criado_em': dataStr});

        for (int item = 0; item < itensParaVender; item++) {
          final lote = lotesDisponiveis[random.nextInt(lotesDisponiveis.length)];
          final qtdVenda = 1.0 + random.nextInt(3);
          final subtotal = qtdVenda * (lote['preco_venda'] as double);
          
          // Atualiza o lote
          await db.execute(
            'UPDATE lotes_produto SET quantidade = quantidade - ?, status = CASE WHEN quantidade - ? <= 0 THEN "ESGOTADO" ELSE status END WHERE id = ?',
            [qtdVenda, qtdVenda, lote['id']]
          );

          await db.insert('venda_itens', {
            'venda_id': vendaId,
            'produto_id': lote['produto_id'],
            'lote_id': lote['id'],
            'quantidade': qtdVenda,
            'preco_unitario': lote['preco_venda'],
            'subtotal': subtotal,
          });

          await db.insert('movimentacoes_estoque', {
            'lote_id': lote['id'],
            'tipo': 'SAIDA',
            'motivo': 'VENDA',
            'quantidade': qtdVenda,
            'criado_em': dataStr,
          });

          totalVenda += subtotal;
        }
        await db.update('vendas', {'valor_total': totalVenda}, where: 'id = ?', whereArgs: [vendaId]);
      }

      // Marcar como vencido o que passou da data
      await db.execute(
        "UPDATE lotes_produto SET status = 'VENCIDO' WHERE data_validade < ? AND status = 'ATIVO'",
        [dataStr]
      );
    }
  }

  static String _format(DateTime dt) => dt.toIso8601String().split('.')[0];
}
