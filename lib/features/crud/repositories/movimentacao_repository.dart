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
  ///
  /// A chave do mapa retornado é o `value` do enum correspondente
  /// (ex.: 'VENDA', 'VENCIMENTO', 'AJUSTE') — use
  /// MotivoMovimentacaoExt.fromString/TipoMovimentacaoExt.fromString para
  /// converter de volta caso precise do label amigável.
  Future<Map<String, int>> getResumoPorMotivo(DateTime desde) async {
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
        r['chave'] as String: (r['total'] as num).toInt(),
    };
  }

  /// Quantidade total com o [motivo] informado, no intervalo [desde, ate).
  /// Usado para o card "Vencidas" (motivo == MotivoMovimentacao.vencimento).
  Future<int> getQuantidadePorMotivo(
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

    return (res.first['total'] as num).toInt();
  }

  /// Valor monetário estimado perdido nos [motivos] informados, no
  /// intervalo [desde, ate). Usa o preço de custo *atual* do lote como
  /// aproximação — não temos o custo histórico no momento exato da perda,
  /// então o valor pode divergir um pouco se o preço de custo do lote
  /// mudou depois do evento. Fica como limitação conhecida.
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
}