import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../services/database_service.dart';

class CartLine {
  final Product product;
  int qty;
  String note;
  CartLine(this.product, {this.qty = 1, this.note = ''});
  int get totalCents => product.priceCents * qty;
}

class CartProvider extends ChangeNotifier {
  final DatabaseService _db;
  CartProvider(this._db);

  final List<CartLine> _lines = [];

  List<CartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;
  int get itemCount => _lines.fold(0, (sum, l) => sum + l.qty);
  int get totalCents => _lines.fold(0, (sum, l) => sum + l.totalCents);

  int qtyOf(Product p) =>
      _lines.where((l) => l.product.id == p.id).fold(0, (s, l) => s + l.qty);

  /// Tapping a product adds one. Same product + no note = same line.
  void add(Product p) {
    final existing = _lines
        .where((l) => l.product.id == p.id && l.note.isEmpty)
        .firstOrNull;
    if (existing != null) {
      existing.qty++;
    } else {
      _lines.add(CartLine(p));
    }
    notifyListeners();
  }

  void increase(CartLine line) {
    line.qty++;
    notifyListeners();
  }

  void decrease(CartLine line) {
    line.qty--;
    if (line.qty <= 0) _lines.remove(line);
    notifyListeners();
  }

  void remove(CartLine line) {
    _lines.remove(line);
    notifyListeners();
  }

  void setNote(CartLine line, String note) {
    line.note = note.trim();
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  /// Saves the order with a SNAPSHOT of each product's name and price,
  /// then empties the cart. Returns the saved order (with its number).
  Future<Order> checkout({
    required String paymentMethod,
    int? cashGivenCents,
    required String cashier,
  }) async {
    final items = _lines
        .map(
          (l) => OrderItem(
            productId: l.product.id,
            name: l.product.name,
            unitPriceCents: l.product.priceCents,
            qty: l.qty,
            note: l.note,
          ),
        )
        .toList();
    final subtotal = totalCents;
    final total = subtotal;
    final change = cashGivenCents == null ? 0 : cashGivenCents - total;
    final saved = await _db.insertOrder(
      Order(
        createdAt: DateTime.now(),
        items: items,
        subtotalCents: subtotal,
        totalCents: total,
        paymentMethod: paymentMethod,
        cashGivenCents: cashGivenCents,
        changeCents: change < 0 ? 0 : change,
        cashier: cashier,
      ),
    );
    clear();
    return saved;
  }
}
