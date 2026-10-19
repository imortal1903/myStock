import 'dart:math';
import 'db.dart';

class DbSeeder {
  static Future<void> popularBanco() async {
    final db = await Db.instance.database;

// 1. LIMPAR DADOS EXISTENTES

    final batch = db.batch();

    batch.execute('DELETE FROM venda_itens');
    batch.execute('DELETE FROM vendas');
    batch.execute('DELETE FROM movimentacoes_estoque');
    batch.execute('DELETE FROM lotes_produto');
    batch.execute('DELETE FROM produtos');
    batch.execute('DELETE FROM categorias');
    batch.execute('DELETE FROM notificacoes');

    await batch.commit(noResult: true);

// 2. CRIAR CATEGORIAS

    final categorias = [
      'Alimentos',
      'Bebidas',
      'Limpeza',
      'Higiene',
      'Hortifruti',
    ];

    final idsCategorias = <String, int>{};

    for (var cat in categorias) {
      final id = await db.insert('categorias', {
        'nome': cat,
        'criado_em': _format(
          DateTime.now().subtract(
            const Duration(days: 370),
          ),
        ),
      });

      idsCategorias[cat] = id;
    }

// 3. CRIAR PRODUTOS

    final prodData = [
      {
        'nome': 'Arroz 5kg',
        'categoria': 'Alimentos',
        'un': 'un',
        'min': 10,
      },
      {
        'nome': 'Feijão Preto 1kg',
        'categoria': 'Alimentos',
        'un': 'un',
        'min': 15,
      },
      {
        'nome': 'Coca-Cola 2L',
        'categoria': 'Bebidas',
        'un': 'un',
        'min': 20,
      },
      {
        'nome': 'Detergente Neutro',
        'categoria': 'Limpeza',
        'un': 'un',
        'min': 30,
      },
      {
        'nome': 'Sabonete 90g',
        'categoria': 'Higiene',
        'un': 'un',
        'min': 50,
      },
      {
        'nome': 'Tomate',
        'categoria': 'Hortifruti',
        'un': 'kg',
        'min': 5,
      },
    ];

    for (var p in prodData) {
      await db.insert('produtos', {
        'nome': p['nome'],
        'categoria_id': idsCategorias[p['categoria']],
        'unidade': p['un'],
        'estoque_min': p['min'],
        'ativo': 1,
        'criado_em': _format(
          DateTime.now().subtract(
            const Duration(days: 368),
          ),
        ),
      });
    }

// 4. CONFIGURAÇÃO DA SIMULAÇÃO

    final random = Random();

    final hoje = DateTime.now();

    final inicio = hoje.subtract(
      const Duration(days: 365),
    );

// 5. SIMULAR CADA DIA DO ÚLTIMO ANO

    for (int i = 0; i <= 365; i++) {
      final dataAtual = inicio.add(
        Duration(days: i),
      );

      final dataStr = _format(dataAtual);

// 5.1 ENTRADA DE NOVOS LOTES

// A cada 15 dias entra um novo lote de cada produto.
      if (i % 15 == 0) {
        final produtos = await db.query('produtos');

        for (var prod in produtos) {
          final precoCusto = 5.0 + random.nextDouble() * 20;

          final precoVenda = precoCusto * 1.4;

          final qtd = 20.0 + random.nextInt(50);

          final loteId = await db.insert(
            'lotes_produto',
            {
              'produto_id': prod['id'],
              'numero_lote':
                  'L${dataAtual.millisecondsSinceEpoch}_${prod['id']}',
              'quantidade': qtd,
              'quantidade_inicial': qtd,
              'preco_custo': precoCusto,
              'preco_venda': precoVenda,
              'data_fabricacao': _format(
                dataAtual.subtract(
                  const Duration(days: 5),
                ),
              ),
              'data_validade': _format(
                dataAtual.add(
                  Duration(
                    days: 30 + random.nextInt(180),
                  ),
                ),
              ),
              'data_entrada': dataStr,
              'status': 'ATIVO',
              'criado_em': dataStr,
            },
          );

// Registra a entrada no estoque.
          await db.insert(
            'movimentacoes_estoque',
            {
              'lote_id': loteId,
              'tipo': 'ENTRADA',
              'motivo': 'COMPRA_FORNECEDOR',
              'quantidade': qtd,
              'criado_em': dataStr,
            },
          );
        }
      }

// 5.2 VENDAS DIÁRIAS

// 2 até 8 vendas por dia.
      final qtdVendas = 2 + random.nextInt(7);

      for (int v = 0; v < qtdVendas; v++) {
        final lotesDisponiveis = await db.rawQuery(
          "SELECT * FROM lotes_produto "
          "WHERE quantidade > 0 "
          "AND status = 'ATIVO' "
          "AND data_validade > ?",
          [dataStr],
        );

        if (lotesDisponiveis.isEmpty) {
          continue;
        }

        final itensParaVender = 1 + random.nextInt(3);

        double totalVenda = 0;

// Cria a venda.
        final vendaId = await db.insert(
          'vendas',
          {
            'valor_total': 0,
            'criado_em': dataStr,
          },
        );

        for (int item = 0; item < itensParaVender; item++) {
          final lotesAtuais = await db.rawQuery(
            "SELECT * FROM lotes_produto "
            "WHERE quantidade > 0 "
            "AND status = 'ATIVO' "
            "AND data_validade > ?",
            [dataStr],
          );

          if (lotesAtuais.isEmpty) {
            break;
          }

// Escolhe um lote aleatório.
          final lote = lotesAtuais[random.nextInt(
            lotesAtuais.length,
          )];

// Quantidade atual disponível no lote.
          final quantidadeDisponivel = (lote['quantidade'] as num).toDouble();

// Sorteia uma quantidade entre 1 e 3.
          final qtdSorteada = (1 + random.nextInt(3)).toDouble();

// Nunca permite vender mais do que existe.
          final qtdVenda = min(
            quantidadeDisponivel,
            qtdSorteada,
          );

          final precoVenda = (lote['preco_venda'] as num).toDouble();

          final subtotal = qtdVenda * precoVenda;

// ATUALIZAR ESTOQUE

          await db.execute(
            'UPDATE lotes_produto '
            'SET quantidade = quantidade - ?, '
            'status = CASE '
            'WHEN quantidade - ? <= 0 '
            'THEN "ESGOTADO" '
            'ELSE status '
            'END '
            'WHERE id = ?',
            [
              qtdVenda,
              qtdVenda,
              lote['id'],
            ],
          );

// REGISTRAR ITEM DA VENDA

          await db.insert(
            'venda_itens',
            {
              'venda_id': vendaId,
              'produto_id': lote['produto_id'],
              'lote_id': lote['id'],
              'quantidade': qtdVenda,
              'preco_unitario': precoVenda,
              'subtotal': subtotal,
            },
          );

// REGISTRAR MOVIMENTAÇÃO DE SAÍDA

          await db.insert(
            'movimentacoes_estoque',
            {
              'lote_id': lote['id'],
              'tipo': 'SAIDA',
              'motivo': 'VENDA',
              'quantidade': qtdVenda,
              'criado_em': dataStr,
            },
          );

          totalVenda += subtotal;
        }

// ATUALIZAR VALOR TOTAL DA VENDA

        await db.update(
          'vendas',
          {
            'valor_total': totalVenda,
          },
          where: 'id = ?',
          whereArgs: [vendaId],
        );
      }

// 5.3 MARCAR LOTES VENCIDOS

      await db.execute(
        "UPDATE lotes_produto "
        "SET status = 'VENCIDO' "
        "WHERE data_validade < ? "
        "AND status = 'ATIVO'",
        [dataStr],
      );
    }
  }

// FORMATAÇÃO DAS DATAS

  static String _format(DateTime dt) {
    return dt.toIso8601String().split('.')[0];
  }
}
