import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../services/data_repository.dart';

/// Today's sales and recent orders (from all phones in a shared cafe).
class OrderProvider extends ChangeNotifier {
  DataRepository? _repo;
  StreamSubscription<List<Order>>? _todaySub;
  StreamSubscription<List<Order>>? _recentSub;
  Timer? _midnight;

  List<Order> todayOrders = [];
  List<Order> orders = []; // last 31 days, newest first

  int get todayTotalCents => todayOrders.fold(0, (s, o) => s + o.totalCents);
  int get todayCount => todayOrders.length;

  void attach(DataRepository repo) {
    if (identical(repo, _repo)) return;
    _repo = repo;
    _subscribe();
  }

  static DateTime _startOfToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _subscribe() {
    final repo = _repo;
    if (repo == null) return;
    _todaySub?.cancel();
    _recentSub?.cancel();
    final today = _startOfToday();
    _todaySub = repo.watchOrders(from: today).listen((list) {
      todayOrders = list;
      notifyListeners();
    });
    _recentSub = repo
        .watchOrders(from: today.subtract(const Duration(days: 30)))
        .listen((list) {
          orders = list;
          notifyListeners();
        });
    // Start a fresh "today" just after midnight.
    _midnight?.cancel();
    final next = today.add(const Duration(days: 1, seconds: 5));
    _midnight = Timer(next.difference(DateTime.now()), _subscribe);
  }

  /// All orders of one day, live (for the daily summary).
  Stream<List<Order>> ordersForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return _repo?.watchOrders(
          from: start,
          to: start.add(const Duration(days: 1)),
        ) ??
        const Stream.empty();
  }

  @override
  void dispose() {
    _todaySub?.cancel();
    _recentSub?.cancel();
    _midnight?.cancel();
    super.dispose();
  }
}
