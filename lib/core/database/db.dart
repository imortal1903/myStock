import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class Db {
  static final Db instance = Db._internal();
  static Database? _db;
  static String? _dbPath;

  Db._internal();

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  /// Caminho absoluto do arquivo .db no disco. Usado pelo sistema de
  /// backup/restauração (GoogleDriveBackupService) para ler/substituir o
  /// arquivo diretamente — não depende de a conexão estar aberta.
  Future<String> caminhoArquivo() async {
    if (_dbPath != null) return _dbPath!;
    final dir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(dir.path, 'estoque'));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    _dbPath = p.join(dbDir.path, 'estoque.db');
    return _dbPath!;
  }

  /// Fecha a conexão atual, se houver uma aberta. Necessário antes de ler
  /// o arquivo .db pra backup (garante que tudo que está no WAL/journal
  /// do SQLite já foi persistido no arquivo principal) e antes de
  /// substituí-lo por um backup restaurado. A próxima chamada a
  /// `database` reabre automaticamente (e roda as migrations pendentes,
  /// se o backup restaurado for de uma versão mais antiga do app).
  Future<void> fecharConexao() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Database> _initDB() async {
    final caminho = await caminhoArquivo();

    return openDatabase(
      caminho,
      version: 2,
      onOpen: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ── MIGRAÇÕES ────────────────────────────────────────────────────────────

  /// v1 → v2:
  ///   - lotes_produto.quantidade_inicial: snapshot imutável da quantidade
  ///     recebida na criação do lote. Necessário para calcular "vendido"
  ///     vs. "restante" por lote sem depender só do log de movimentações
  ///     (que pode estar incompleto para entradas antigas).
  ///   - movimentacoes_estoque.motivo: motivo estruturado da movimentação
  ///     (ex.: distinguir perda por VENCIMENTO de perda por AVARIA no
  ///     dashboard de Análise).
  ///
  /// Observação importante: por limitação do ALTER TABLE do SQLite, as
  /// constraints CHECK dessas colunas só são aplicadas em bancos criados
  /// do zero (via _onCreate). Em bancos migrados a partir da v1, a
  /// validação de motivo/quantidade fica a cargo da camada Dart — os
  /// enums TipoMovimentacao/MotivoMovimentacao e o construtor Lote.novo()
  /// cobrem isso na prática.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Declarada como INTEGER por herança do tipo original de `quantidade`,
      // mas isso não impede valores fracionários: por afinidade de coluna,
      // o SQLite guarda um REAL (ex.: 1.5) sem truncar quando o valor não é
      // convertível sem perdas para inteiro. Não é necessário migrar para
      // REAL para suportar vendas fracionadas (kg/g/L/mL) introduzidas
      // depois — ver também os comentários em _onCreate.
      await db.execute(
        'ALTER TABLE lotes_produto ADD COLUMN quantidade_inicial INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE movimentacoes_estoque ADD COLUMN motivo TEXT',
      );

      // Backfill: não existe registro histórico da quantidade inicial real
      // de lotes já cadastrados antes desta migration. O melhor proxy
      // disponível é a quantidade atual — isso subestima o valor real para
      // lotes que já sofreram saídas antes da migration, mas é o único
      // dado que temos. A partir daqui, todo novo lote grava o valor certo
      // (veja Lote.novo() em lote.dart).
      await db.rawUpdate('''
        UPDATE lotes_produto
        SET quantidade_inicial = quantidade
        WHERE quantidade_inicial = 0
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final b = db.batch();

    b.execute("""
    CREATE TABLE categorias(
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      nome      TEXT NOT NULL,
      criado_em TEXT NOT NULL DEFAULT(datetime('now'))
    )""");

    b.execute("""
    CREATE TABLE produtos(
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      nome          TEXT NOT NULL,
      descricao     TEXT,
      codigo_barras TEXT UNIQUE,
      categoria_id  INTEGER,
      estoque_min   INTEGER,
      ativo         INTEGER NOT NULL DEFAULT 1,
      criado_em     TEXT NOT NULL DEFAULT(datetime('now')),
      unidade       TEXT NOT NULL,
      FOREIGN KEY(categoria_id) REFERENCES categorias(id) ON DELETE SET NULL
    )""");

    b.execute("""
    CREATE TABLE lotes_produto(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      produto_id INTEGER NOT NULL,
      numero_lote TEXT,
      quantidade REAL NOT NULL CHECK(quantidade>=0),
      quantidade_inicial REAL NOT NULL CHECK(quantidade_inicial>=0),
      preco_custo REAL NOT NULL,
      preco_venda REAL NOT NULL,
      data_fabricacao TEXT,
      data_validade TEXT NOT NULL,
      data_entrada TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'ATIVO'
        CHECK(status IN('ATIVO','VENCIDO','ESGOTADO')),
      criado_em TEXT NOT NULL DEFAULT(datetime('now')),
      FOREIGN KEY(produto_id) REFERENCES produtos(id) ON DELETE CASCADE
    )""");

    b.execute("""
    CREATE TABLE movimentacoes_estoque(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lote_id INTEGER NOT NULL,
      tipo TEXT NOT NULL CHECK(tipo IN('ENTRADA','SAIDA','AJUSTE','PERDA')),
      motivo TEXT CHECK(motivo IS NULL OR motivo IN(
        'VENDA','VENCIMENTO','AVARIA','ROUBO','CONTAGEM_INVENTARIO',
        'COMPRA_FORNECEDOR','DEVOLUCAO_CLIENTE','OUTRO'
      )),
      quantidade REAL NOT NULL CHECK(quantidade>=0),
      observacao TEXT,
      criado_em TEXT NOT NULL DEFAULT(datetime('now')),
      FOREIGN KEY(lote_id) REFERENCES lotes_produto(id) ON DELETE CASCADE
    )""");

    b.execute("""
    CREATE TABLE vendas(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      valor_total REAL NOT NULL,
      criado_em TEXT NOT NULL DEFAULT(datetime('now'))
    )""");

    b.execute("""
    CREATE TABLE venda_itens(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      venda_id INTEGER NOT NULL,
      produto_id INTEGER NOT NULL,
      lote_id INTEGER NOT NULL,
      quantidade REAL NOT NULL CHECK(quantidade>=0),
      preco_unitario REAL NOT NULL,
      subtotal REAL NOT NULL,
      FOREIGN KEY(venda_id) REFERENCES vendas(id) ON DELETE CASCADE,
      FOREIGN KEY(produto_id) REFERENCES produtos(id),
      FOREIGN KEY(lote_id) REFERENCES lotes_produto(id)
    )""");

    b.execute("""
    CREATE TABLE notificacoes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tipo TEXT NOT NULL CHECK(tipo IN('VALIDADE_PROXIMA','PRODUTO_VENCIDO','ESTOQUE_BAIXO')),
      produto_id INTEGER,
      lote_id INTEGER,
      mensagem TEXT NOT NULL,
      visualizada INTEGER NOT NULL DEFAULT 0,
      criado_em TEXT NOT NULL DEFAULT(datetime('now')),
      FOREIGN KEY(produto_id) REFERENCES produtos(id) ON DELETE CASCADE,
      FOREIGN KEY(lote_id) REFERENCES lotes_produto(id) ON DELETE CASCADE
    )""");

    b.execute("""
      CREATE TABLE notification_config(
      id              INTEGER PRIMARY KEY,
      ativado         INTEGER NOT NULL DEFAULT 1,
      diasAntes       INTEGER NOT NULL DEFAULT 3,
      hora            INTEGER NOT NULL DEFAULT 9,
      minuto          INTEGER NOT NULL DEFAULT 0,
      intervaloHoras  INTEGER NOT NULL DEFAULT 24
    )""");

    b.insert('notification_config', {
      'id': 1,
      'ativado': 1,
      'diasAntes': 3,
      'hora': 9,
      'minuto': 0,
      'intervaloHoras': 24
    });

    b.execute("CREATE INDEX idx_produto_nome            ON produtos(nome)");
    b.execute("CREATE INDEX idx_produto_categoria       ON produtos(categoria_id)");
    b.execute("CREATE INDEX idx_lote_produto            ON lotes_produto(produto_id)");
    b.execute("CREATE INDEX idx_lote_validade           ON lotes_produto(data_validade)");
    b.execute("CREATE INDEX idx_movimentacao_lote       ON movimentacoes_estoque(lote_id)");
    b.execute("CREATE INDEX idx_venda_data              ON vendas(criado_em)");
    b.execute("CREATE INDEX idx_venda_itens_venda       ON venda_itens(venda_id)");
    b.execute("CREATE INDEX idx_venda_itens_produto     ON venda_itens(produto_id)");
    b.execute("CREATE INDEX idx_notificacao_visualizada ON notificacoes(visualizada)");

    await b.commit(noResult: true);
  }
}