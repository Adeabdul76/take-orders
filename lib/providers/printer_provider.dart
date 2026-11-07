import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/printer_device.dart';
import '../services/zywell_printer_service.dart';

/// Screens use this provider. It is the only bridge to the printer service,
/// so no Bluetooth code ever lives in a screen.
class PrinterProvider extends ChangeNotifier {
  final ZywellPrinterService _service;

  PrinterProvider(this._service) {
    _statusSub = _service.statusStream.listen((_) => notifyListeners());
    _warnSub = _service.disconnectWarnings.listen((msg) {
      lastWarning = msg;
      notifyListeners();
    });
  }

  StreamSubscription<PrinterStatus>? _statusSub;
  StreamSubscription<String>? _warnSub;
  StreamSubscription<List<PrinterDevice>>? _scanSub;

  List<PrinterDevice> devices = [];
  bool scanning = false;
  bool scanFinishedEmpty = false;
  PrinterDevice? savedDevice;

  /// Set when the printer drops unexpectedly. Screens show it once, then clear.
  String? lastWarning;

  PrinterStatus get status => _service.getStatus();
  bool get isConnected =>
      status == PrinterStatus.connected || status == PrinterStatus.printing;
  PrinterDevice? get device => _service.currentDevice ?? savedDevice;

  Future<bool> checkBluetoothOn() => _service.checkBluetoothOn();
  Future<bool> requestPermissions() => _service.requestPermissions();

  void clearWarning() {
    lastWarning = null;
  }

  /// Called once at app start.
  Future<void> init() async {
    savedDevice = await _service.loadDefault();
    notifyListeners();
    if (savedDevice != null) {
      await _service.autoReconnect();
      notifyListeners();
    }
  }

  /// Returns a friendly error message, or null if scanning started.
  Future<String?> startScan() async {
    if (!await _service.requestPermissions()) {
      return ZywellMessages.permissionsDenied;
    }
    if (!await _service.checkBluetoothOn()) {
      return ZywellMessages.bluetoothOffPopup;
    }
    await _scanSub?.cancel();
    devices = [];
    scanning = true;
    scanFinishedEmpty = false;
    notifyListeners();
    _scanSub = _service.scanDevices().listen(
      (list) {
        devices = list;
        notifyListeners();
      },
      onDone: () {
        scanning = false;
        scanFinishedEmpty = devices.isEmpty;
        notifyListeners();
      },
    );
    return null;
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    scanning = false;
    notifyListeners();
  }

  Future<String?> connect(PrinterDevice d) async {
    await stopScan();
    final error = await _service.connect(d);
    if (error == null) savedDevice = d;
    notifyListeners();
    return error;
  }

  Future<String?> reconnect() async {
    final d = device;
    if (d == null) return ZywellMessages.notConnected;
    return connect(d);
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    notifyListeners();
  }

  Future<void> forget() async {
    await _service.disconnect(forget: true);
    savedDevice = null;
    notifyListeners();
  }

  Future<PrintResult> printReceipt(
    Order order,
    ReceiptSettings settings, {
    int copies = 1,
  }) async {
    final r = await _service.printReceipt(order, settings, copies: copies);
    notifyListeners();
    return r;
  }

  Future<PrintResult> printTest(ReceiptSettings settings) async {
    final r = await _service.printTestReceipt(settings);
    notifyListeners();
    return r;
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _warnSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }
}
