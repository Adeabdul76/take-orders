import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/database_service.dart';

/// The shop's own products. The app starts EMPTY: nothing is hard-coded.
class ProductProvider extends ChangeNotifier {
  final DatabaseService _db;
  ProductProvider(this._db);

  List<Product> _products = [];
  bool loaded = false;

  List<Product> get products => List.unmodifiable(_products);
  List<Product> get availableProducts =>
      _products.where((p) => p.available).toList();

  /// Categories the user has created (taken from their products).
  List<String> get categories {
    final set = <String>{};
    for (final p in _products) {
      if (p.category.trim().isNotEmpty) set.add(p.category.trim());
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> load() async {
    _products = await _db.getProducts();
    loaded = true;
    notifyListeners();
  }

  Future<void> add(Product p) async {
    await _db.insertProduct(p);
    await load();
  }

  Future<void> update(Product p) async {
    await _db.updateProduct(p);
    await load();
  }

  Future<void> delete(Product p) async {
    if (p.id == null) return;
    await _db.deleteProduct(p.id!);
    await load();
  }

  Future<void> duplicate(Product p) async {
    await _db.insertProduct(
      Product(
        name: '${p.name} (copy)',
        priceCents: p.priceCents,
        category: p.category,
        imagePath: p.imagePath,
        emoji: p.emoji,
        available: p.available,
      ),
    );
    await load();
  }

  Future<void> setAvailable(Product p, bool available) =>
      update(p.copyWith(available: available));
}
