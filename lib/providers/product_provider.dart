import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/data_repository.dart';

/// The shop's own products. The app starts EMPTY: nothing is hard-coded.
/// In a shared cafe, changes made on one phone appear on all phones.
class ProductProvider extends ChangeNotifier {
  DataRepository? _repo;
  StreamSubscription<List<Product>>? _sub;

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
    return set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void attach(DataRepository repo) {
    if (identical(repo, _repo)) return;
    _repo = repo;
    _sub?.cancel();
    loaded = false;
    _sub = repo.watchProducts().listen((list) {
      _products = list;
      loaded = true;
      notifyListeners();
    });
  }

  Future<void> save(Product p) async => _repo?.saveProduct(p);

  Future<void> delete(Product p) async {
    if (p.id != null) await _repo?.deleteProduct(p.id!);
  }

  Future<void> duplicate(Product p) => save(
    Product(
      name: '${p.name} (copy)',
      priceCents: p.priceCents,
      category: p.category,
      imageData: p.imageData,
      imagePath: p.imagePath,
      emoji: p.emoji,
      available: p.available,
    ),
  );

  Future<void> setAvailable(Product p, bool available) =>
      save(p.copyWith(available: available));

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
