import '../../../core/database/db.dart';
import '../models/movimentacao_estoque.dart';

class MovimentacaoRepository {
  final Db _db;
  MovimentacaoRepository({Db? db}) : _db = db ?? Db.instance;

  Future<int> insert(MovimentacaoEstoque m) async {
    final db = await _db.database;
    return db.insert('movimentacoes_estoque', m.toMap());
  }

  /// Total movimentado agrupado por motivo (ou por tipo, quando o motivo
  /// não foi preenchido) desde [desde]. Base do gráfico "para onde o
  /// estoque está indo" na aba Análise.
  Future<Map<String, double>> getResumoPorMotivo(DateTime desde) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(motivo, tipo) AS chave,
        SUM(quantidade) AS total
      FROM movimentacoes_estoque
      WHERE criado_em >= ?
      GROUP BY chave
      ORDER BY total DESC
    ''', [desde.toIso8601String()]);

    return {
      for (final r in rows)
        r['chave'] as String: (r['total'] as num).toDouble(),
    };
  }

  /// Quantidade total com o [motivo] informado, no intervalo [desde, ate).
  /// Usado para o card "Vencidas" (motivo == MotivoMovimentacao.vencimento).
  Future<double> getQuantidadePorMotivo(
      DateTime desde,
      DateTime ate,
      MotivoMovimentacao motivo,
      ) async {
    final db = await _db.database;
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(quantidade), 0) AS total
      FROM movimentacoes_estoque
      WHERE criado_em >= ? AND criado_em < ? AND motivo = ?
    ''', [desde.toIso8601String(), ate.toIso8601String(), motivo.value]);

    return (res.first['total'] as num).toDouble();
  }

  /// Valor monetário estimado perdido nos [motivos] informados, no
  /// intervalo [desde, ate).
  Future<double> getValorPerdido(
      DateTime desde,
      DateTime ate,
      List<MotivoMovimentacao> motivos,
      ) async {
    if (motivos.isEmpty) return 0;
    final db = await _db.database;
    final placeholders = List.filled(motivos.length, '?').join(',');

    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(m.quantidade * l.preco_custo), 0) AS valor
      FROM movimentacoes_estoque m
      JOIN lotes_produto l ON l.id = m.lote_id
      WHERE m.criado_em >= ? AND m.criado_em < ?
        AND m.motivo IN ($placeholders)
    ''', [
      desde.toIso8601String(),
      ate.toIso8601String(),
      ...motivos.map((e) => e.value),
    ]);

    return (res.first['valor'] as num).toDouble();
  }

  /// Quantidade vendida (motivo == venda) de cada produto desde [desde].
  /// Produtos sem nenhuma venda no período simplesmente não aparecem no
  /// mapa retornado.
  Future<Map<int, double>> getVendidoPorProdutoDesde(DateTime desde) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        l.produto_id AS produto_id,
        SUM(m.quantidade) AS total
      FROM movimentacoes_estoque m
      JOIN lotes_produto l ON l.id = m.lote_id
      WHERE m.criado_em >= ? AND m.motivo = ?
      GROUP BY l.produto_id
    ''', [desde.toIso8601String(), MotivoMovimentacao.venda.value]);

    return {
      for (final r in rows)
        r['produto_id'] as int: (r['total'] as num).toDouble(),
    };
  }
}