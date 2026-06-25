import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(dir.path, 'estoque'));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);

    final path = p.join(dbDir.path, 'estoque.db');

    return openDatabase(          // ← sqflite nativo, sem databaseFactory
      path,
      version: 1,
      onOpen: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
  }

  // sqflite não suporta múltiplos statements por execute().
  // Usamos batch para rodar cada DDL individualmente numa única transação.
  Future<void> _onCreate(Database db, int version) async {
    final b = db.batch();

    // ── Categorias ────────────────────────────────────────────────────────────
    b.execute('''
      CREATE TABLE categorias (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        nome      TEXT    NOT NULL,
        criado_em TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Produtos ──────────────────────────────────────────────────────────────
    b.execute('''
      CREATE TABLE produtos (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        nome          TEXT    NOT NULL,
        descricao     TEXT,
        codigo_barras TEXT,
        categoria_id  INTEGER,
        estoque_min   INTEGER,
        ativo         INTEGER NOT NULL DEFAULT 1,
        criado_em     TEXT    NOT NULL DEFAULT (datetime('now')),
        unidade       TEXT    NOT NULL,
        FOREIGN KEY (categoria_id) REFERENCES categorias(id)
      )
    ''');

    // ── Lotes dos Produtos ────────────────────────────────────────────────────
    b.execute('''
      CREATE TABLE lotes_produto (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        produto_id      INTEGER NOT NULL,
        numero_lote     TEXT,
        quantidade      INTEGER NOT NULL CHECK (quantidade >= 0),
        preco_custo     REAL,
        data_fabricacao TEXT,
        data_validade   TEXT    NOT NULL,
        data_entrada    TEXT    NOT NULL,
        status          TEXT    NOT NULL DEFAULT 'ATIVO'
                        CHECK (status IN ('ATIVO','VENCIDO','ESGOTADO')),
        criado_em       TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE
      )
    ''');

    // ── Movimentações de Estoque ──────────────────────────────────────────────
    b.execute('''
      CREATE TABLE movimentacoes_estoque (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        lote_id    INTEGER NOT NULL,
        tipo       TEXT    NOT NULL
                   CHECK (tipo IN ('ENTRADA','SAIDA','AJUSTE','PERDA')),
        quantidade INTEGER NOT NULL CHECK (quantidade >= 0),
        observacao TEXT,
        criado_em  TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (lote_id) REFERENCES lotes_produto(id)
      )
    ''');

    // ── Vendas ────────────────────────────────────────────────────────────────
    b.execute('''
      CREATE TABLE vendas (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        valor_total REAL    NOT NULL,
        criado_em   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Itens da Venda ────────────────────────────────────────────────────────
    b.execute('''
      CREATE TABLE venda_itens (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        venda_id       INTEGER NOT NULL,
        produto_id     INTEGER NOT NULL,
        lote_id        INTEGER NOT NULL,
        quantidade     INTEGER NOT NULL CHECK (quantidade >= 0),
        preco_unitario REAL    NOT NULL,
        subtotal       REAL    NOT NULL,
        FOREIGN KEY (venda_id)   REFERENCES vendas(id),
        FOREIGN KEY (produto_id) REFERENCES produtos(id),
        FOREIGN KEY (lote_id)    REFERENCES lotes_produto(id)
      )
    ''');

    // ── Favoritos ─────────────────────────────────────────────────────────────
    b.execute('''
      CREATE TABLE produtos_favoritos (
        produto_id INTEGER PRIMARY KEY,
        criado_em  TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE
      )
    ''');

    // ── Notificações ──────────────────────────────────────────────────────────
    b.execute('''
      CREATE TABLE notificacoes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo        TEXT    NOT NULL
                    CHECK (tipo IN ('VALIDADE_PROXIMA','PRODUTO_VENCIDO','ESTOQUE_BAIXO')),
        produto_id  INTEGER,
        lote_id     INTEGER,
        mensagem    TEXT    NOT NULL,
        visualizada INTEGER NOT NULL DEFAULT 0,
        criado_em   TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE, 
        FOREIGN KEY (lote_id)    REFERENCES lotes_produto(id) ON DELETE CASCADE
      )
    ''');

    // ── Configuração das notificações ─────────────────────────────────────────
    b.execute('''
        CREATE TABLE notification_config (
          id               INTEGER PRIMARY KEY,
          ativado          INTEGER NOT NULL DEFAULT 1,
          diasAntes        INTEGER NOT NULL DEFAULT 3,
          hora             INTEGER NOT NULL DEFAULT 9,
          minuto           INTEGER NOT NULL DEFAULT 0,
          intervaloHoras   INTEGER NOT NULL DEFAULT 24
        )
    ''');

    b.insert(
        'notification_config',{
          'id': 1,
          'ativado': 1,
          'diasAntes': 3,
          'hora': 9,
          'minuto': 0,
          'intervaloHoras': 24,});


    // ── Índices ───────────────────────────────────────────────────────────────
    b.execute('CREATE INDEX idx_produto_nome      ON produtos(nome)');
    b.execute('CREATE INDEX idx_lote_produto      ON lotes_produto(produto_id)');
    b.execute('CREATE INDEX idx_lote_validade     ON lotes_produto(data_validade)');
    b.execute('CREATE INDEX idx_vendas_data       ON vendas(criado_em)');
    b.execute('CREATE INDEX idx_notif_visualizada ON notificacoes(visualizada)');

    await b.commit(noResult: true);
  }
}