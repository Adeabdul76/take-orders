import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../services/database_service.dart';

/// Past orders and today's sales.
class OrderProvider extends ChangeNotifier {
  final DatabaseService _db;
  OrderProvider(this._db);

  List<Order> orders = [];
  int todayTotalCents = 0;
  int todayCount = 0;

  Future<void> refreshToday() async {
    final s = await _db.getTodaySales();
    todayTotalCents = s.totalCents;
    todayCount = s.count;
    notifyListeners();
  }

  Future<void> loadOrders() async {
    orders = await _db.getOrders();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    await refreshToday();
    await loadOrders();
  }
}
