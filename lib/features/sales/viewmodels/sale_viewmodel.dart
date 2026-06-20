import 'package:flutter/material.dart';

import '../../crud/models/lote.dart';
import '../../crud/models/produto.dart';

/// Representa uma venda registrada.
class Sale {
  final String id;
  final Produto produto;
  final Lote lote;
  final int quantidade;
  final double totalPago;
  final DateTime vendidoEm;

  const Sale({
    required this.id,
    required this.produto,
    required this.lote,
    required this.quantidade,
    required this.totalPago,
    required this.vendidoEm,
  });

  double get valorUnitario =>
      quantidade > 0 ? totalPago / quantidade : 0;

  String get dataFormatada {
    return '${vendidoEm.day.toString().padLeft(2, '0')}/'
        '${vendidoEm.month.toString().padLeft(2, '0')}/'
        '${vendidoEm.year}';
  }
}

class SaleViewModel extends ChangeNotifier {
  // ───────────────── STATE ─────────────────

  final List<Sale> _vendas = [];

  // ───────────────── GETTERS ─────────────────

  List<Sale> get vendas => List.unmodifiable(_vendas);

  bool get isEmpty => _vendas.isEmpty;

  double get totalGeral {
    return _vendas.fold(
      0,
          (sum, venda) => sum + venda.totalPago,
    );
  }

  int get totalItens {
    return _vendas.fold(
      0,
          (sum, venda) => sum + venda.quantidade,
    );
  }

  // ───────────────── ACTIONS ─────────────────

  void registrarVenda({
    required Produto produto,
    required Lote lote,
    required int quantidade,
    required double totalPago,
  }) {
    final venda = Sale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      produto: produto,
      lote: lote,
      quantidade: quantidade,
      totalPago: totalPago,
      vendidoEm: DateTime.now(),
    );

    _vendas.insert(0, venda);

    notifyListeners();
  }

  void removerVenda(String id) {
    _vendas.removeWhere((v) => v.id == id);

    notifyListeners();
  }

  void limparVendas() {
    _vendas.clear();

    notifyListeners();
  }
}