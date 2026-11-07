import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_settings.dart';
import '../services/data_repository.dart';
import '../services/database_service.dart';
import '../services/zywell_printer_service.dart' show ReceiptSettings;

/// Shop details (shared by all phones of the cafe) + this phone's own
/// settings (cashier name, paper size, auto-print, copies).
class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  DataRepository? _repo;
  StreamSubscription<ShopSettings?>? _shopSub;

  // Shared shop details
  ShopSettings shop = const ShopSettings();
  Uint8List? logoBytes;

  // This phone only
  bool setupDone = false;
  String cashier = 'Owner';
  int paperMm = 80; // 80 (default) or 58
  bool autoPrint = false;
  int copies = 1; // 1 or 2
  int _orderCounter = 0;

  String get shopName => shop.name;
  String get shopPhone => shop.phone;
  String get shopAddress => shop.address;
  String get currency => shop.currency;
  String get footer => shop.footer;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    setupDone = p.getBool('setup_done') ?? false;
    cashier = p.getString('cashier') ?? 'Owner';
    paperMm = p.getInt('paper_mm') ?? 80;
    autoPrint = p.getBool('auto_print') ?? false;
    copies = p.getInt('copies') ?? 1;
    final counter = p.getInt('order_counter');
    // First run after the update: carry on from the old order numbers.
    _orderCounter = counter ?? await LocalRepository.instance.maxOrderId();
    notifyListeners();
  }

  void attach(DataRepository repo) {
    if (identical(repo, _repo)) return;
    _repo = repo;
    _shopSub?.cancel();
    _shopSub = repo.watchShop().listen((s) {
      final newShop = s ?? const ShopSettings();
      if (newShop.logoPng != shop.logoPng) {
        logoBytes = _decode(newShop.logoPng);
      }
      shop = newShop;
      notifyListeners();
    });
  }

  static Uint8List? _decode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  ReceiptSettings get receiptSettings => ReceiptSettings(
    shopName: shop.name,
    shopPhone: shop.phone,
    shopAddress: shop.address,
    currency: shop.currency,
    paperMm: paperMm,
    footer: shop.footer,
    logoPng: logoBytes,
  );

  /// Next order number for THIS phone, e.g. "042" or (shared cafe) "B042".
  /// Each phone has its own letter, so two phones never use the same number,
  /// even when offline.
  Future<String> nextOrderNumber(String deviceTag) async {
    _orderCounter++;
    await (_prefs ?? await SharedPreferences.getInstance()).setInt(
      'order_counter',
      _orderCounter,
    );
    return '$deviceTag${_orderCounter.toString().padLeft(3, '0')}';
  }

  /// Order numbers start again from 1 (used when a phone joins a cafe).
  Future<void> resetOrderCounter() async {
    _orderCounter = 0;
    await (_prefs ?? await SharedPreferences.getInstance()).setInt(
      'order_counter',
      0,
    );
  }

  Future<void> saveShop(ShopSettings newShop) async {
    if (newShop.logoPng != shop.logoPng) logoBytes = _decode(newShop.logoPng);
    shop = newShop;
    notifyListeners();
    await _repo?.saveShop(newShop);
  }

  Future<void> saveDevice({
    required String cashierName,
    required int paper,
  }) async {
    cashier = cashierName.trim().isEmpty ? 'Owner' : cashierName.trim();
    paperMm = paper;
    setupDone = true;
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString('cashier', cashier);
    await p.setInt('paper_mm', paperMm);
    await p.setBool('setup_done', true);
    notifyListeners();
  }

  Future<void> setPaperMm(int mm) async {
    paperMm = mm;
    notifyListeners();
    await (_prefs ?? await SharedPreferences.getInstance()).setInt(
      'paper_mm',
      mm,
    );
  }

  Future<void> setAutoPrint(bool on) async {
    autoPrint = on;
    notifyListeners();
    await (_prefs ?? await SharedPreferences.getInstance()).setBool(
      'auto_print',
      on,
    );
  }

  Future<void> setCopies(int n) async {
    copies = n;
    notifyListeners();
    await (_prefs ?? await SharedPreferences.getInstance()).setInt('copies', n);
  }

  @override
  void dispose() {
    _shopSub?.cancel();
    super.dispose();
  }
}
