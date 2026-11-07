import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/zywell_printer_service.dart' show ReceiptSettings;

/// Shop details and app settings, saved on the phone.
class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  bool setupDone = false;
  String shopName = '';
  String shopPhone = '';
  String shopAddress = '';
  String cashier = 'Owner';
  String currency = 'RM'; // "RM" or "MYR"
  int paperMm = 80; // 80 (default) or 58
  bool autoPrint = false;
  int copies = 1; // 1 or 2
  String footer = 'Thank you! Come again!';

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    setupDone = p.getBool('setup_done') ?? false;
    shopName = p.getString('shop_name') ?? '';
    shopPhone = p.getString('shop_phone') ?? '';
    shopAddress = p.getString('shop_address') ?? '';
    cashier = p.getString('cashier') ?? 'Owner';
    currency = p.getString('currency') ?? 'RM';
    paperMm = p.getInt('paper_mm') ?? 80;
    autoPrint = p.getBool('auto_print') ?? false;
    copies = p.getInt('copies') ?? 1;
    footer = p.getString('footer') ?? 'Thank you! Come again!';
    notifyListeners();
  }

  ReceiptSettings get receiptSettings => ReceiptSettings(
    shopName: shopName,
    shopPhone: shopPhone,
    shopAddress: shopAddress,
    currency: currency,
    paperMm: paperMm,
    footer: footer,
  );

  Future<void> saveShop({
    required String name,
    required String phone,
    required String address,
    required String cashierName,
    required String currencyCode,
    required int paper,
    required String footerText,
  }) async {
    shopName = name.trim();
    shopPhone = phone.trim();
    shopAddress = address.trim();
    cashier = cashierName.trim().isEmpty ? 'Owner' : cashierName.trim();
    currency = currencyCode;
    paperMm = paper;
    footer = footerText.trim().isEmpty
        ? 'Thank you! Come again!'
        : footerText.trim();
    setupDone = true;
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString('shop_name', shopName);
    await p.setString('shop_phone', shopPhone);
    await p.setString('shop_address', shopAddress);
    await p.setString('cashier', cashier);
    await p.setString('currency', currency);
    await p.setInt('paper_mm', paperMm);
    await p.setString('footer', footer);
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
}
