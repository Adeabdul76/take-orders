// ALL Bluetooth + ESC/POS code for the ZYWELL printer lives in this file.
// Screens and widgets must never talk to Bluetooth directly; they go through
// PrinterProvider, which calls this service.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../models/printer_device.dart';
import '../utils/money.dart';

// ============================================================================
// Friendly messages (never show raw errors to the cashier)
// ============================================================================

class ZywellMessages {
  static const bluetoothOff = 'Please turn on Bluetooth';
  static const bluetoothOffPopup = 'Turn on Bluetooth to connect to ZYWELL';
  static const permissionsWhy = 'Needed to find your ZYWELL printer';
  static const permissionsDenied =
      'Bluetooth permission is off. Allow "Nearby devices" and "Location" '
      'for this app in phone Settings, then try again.';
  static const notFound =
      'ZYWELL not found.\n'
      '1. Turn ZYWELL ON\n'
      '2. Blue light blinking? (blinking = not connected yet)\n'
      '3. Move phone close\n'
      '4. Tap Scan again';
  static const scanning = 'Scanning for ZYWELL...';
  static const pinHint = 'If asked for PIN, try 0000 (or 1234)';
  static const connectFailed =
      'Could not connect to ZYWELL. Make sure it is '
      'ON and close to the phone, then try again.';
  static const disconnectedMidPrint =
      'Print failed. ZYWELL disconnected. Reconnect and tap Reprint';
  static const notConnected = 'ZYWELL not connected - Tap to connect';
  static const disconnectedWarning =
      'ZYWELL disconnected. If prints were faint, the battery may be low - '
      'please charge it.';
  static const labelMode =
      'Your ZYWELL is in Label Mode. Hold SET button to switch to '
      'ESC / Receipt Mode';
  static const modeCheck =
      'Is your ZYWELL in Receipt Mode? If the receipt '
      'prints blank, prints strange symbols, or feeds a lot of empty paper, '
      'your ZYWELL is in Label Mode. Hold the SET button to switch to '
      'ESC / Receipt Mode, then print a test receipt again.';
  static const printOk = 'Printed';
}

// ============================================================================
// Status
// ============================================================================

/// Note: "paperOut" cannot be read back from most ZYWELL portable models over
/// Bluetooth, so the app only shows it if the printer reports it in future.
enum PrinterStatus {
  disconnected,
  connecting,
  connected,
  printing,
  error,
  paperOut,
}

extension PrinterStatusLabel on PrinterStatus {
  String get label => switch (this) {
    PrinterStatus.disconnected => 'Disconnected',
    PrinterStatus.connecting => 'Connecting...',
    PrinterStatus.connected => 'Connected',
    PrinterStatus.printing => 'Printing...',
    PrinterStatus.error => 'Error',
    PrinterStatus.paperOut => 'Paper Out',
  };
}

class PrintResult {
  final bool success;
  final String message;
  const PrintResult(this.success, this.message);
}

// ============================================================================
// Receipt settings + layout
// ============================================================================

class ReceiptSettings {
  final String shopName;
  final String shopPhone;
  final String shopAddress;
  final String currency; // "RM" or "MYR"
  final int paperMm; // 80 or 58
  final String footer;

  const ReceiptSettings({
    required this.shopName,
    this.shopPhone = '',
    this.shopAddress = '',
    this.currency = 'RM',
    this.paperMm = 80,
    this.footer = 'Thank you! Come again!',
  });
}

/// Fixed column widths. 80mm paper = 48 chars, 58mm paper = 32 chars.
/// We use ESC/POS Font A (12x24 dots): 576 dots / 12 = 48 chars on 80mm,
/// 384 dots / 12 = 32 chars on 58mm. Using 32-char layout on 80mm paper (or
/// mixing fonts) is what caused the old squashed / doubled receipt.
class ReceiptLayout {
  final int cols;
  final int nameW;
  final int qtyW;
  final int amountW;
  final int gap;

  const ReceiptLayout._(
    this.cols,
    this.nameW,
    this.qtyW,
    this.amountW,
    this.gap,
  );

  /// 80mm: Item 24 left | Qty 6 center | Amount 12 right, 2 gaps of 3 = 48.
  static const mm80 = ReceiptLayout._(48, 24, 6, 12, 3);

  /// 58mm: Item 16 left | Qty 4 center | Amount 10 right, 2 gaps of 1 = 32.
  static const mm58 = ReceiptLayout._(32, 16, 4, 10, 1);

  static ReceiptLayout forPaper(int paperMm) => paperMm == 58 ? mm58 : mm80;
}

/// Raw ESC/POS command bytes.
class EscPos {
  static const init = [0x1B, 0x40]; // ESC @  reset printer
  static const fontA = [0x1B, 0x4D, 0x00]; // ESC M 0
  static const codePage437 = [0x1B, 0x74, 0x00]; // ESC t 0
  static const alignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const alignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const alignRight = [0x1B, 0x61, 0x02]; // ESC a 2
  static const boldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const boldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const sizeNormal = [0x1D, 0x21, 0x00]; // GS ! 0
  static const sizeDouble = [0x1D, 0x21, 0x11]; // GS ! 0x11 (2x wide, 2x tall)
  static const lineFeed = [0x0A];
  static const cut = [0x1D, 0x56, 0x00]; // GS V 0  full cut
  static List<int> feedLines(int n) => [0x1B, 0x64, n]; // ESC d n
}

enum _Align { left, center, right }

/// Builds a receipt ONCE into a single list of bytes. Every line is written
/// exactly once and always ends with a single line feed, so nothing can be
/// printed twice or on top of another line.
class ReceiptBuilder {
  final ReceiptLayout layout;
  final List<int> _bytes = [];
  final List<String> _lines = []; // plain-text copy, used for tests/preview

  ReceiptBuilder(int paperMm) : layout = ReceiptLayout.forPaper(paperMm) {
    _bytes
      ..addAll(EscPos.init)
      ..addAll(EscPos.fontA)
      ..addAll(EscPos.codePage437)
      ..addAll(EscPos.alignLeft)
      ..addAll(EscPos.boldOff)
      ..addAll(EscPos.sizeNormal);
  }

  int get cols => layout.cols;
  List<String> get lines => List.unmodifiable(_lines);

  /// Thermal printers only know basic characters. Replace anything else.
  static String sanitize(String s) {
    final replaced = s
        .replaceAll(RegExp('[‘’]'), "'")
        .replaceAll(RegExp('[“”]'), '"')
        .replaceAll(RegExp('[–—]'), '-')
        .replaceAll(RegExp(r'[\r\n\t]'), ' ');
    final buf = StringBuffer();
    for (final rune in replaced.runes) {
      buf.writeCharCode(rune >= 32 && rune <= 126 ? rune : 0x3F); // '?'
    }
    return buf.toString();
  }

  /// Splits text into pieces no longer than [width], breaking at spaces.
  static List<String> wrap(String text, int width) {
    final words = sanitize(text).trim().split(RegExp(r' +'));
    final out = <String>[];
    var current = '';
    for (var word in words) {
      while (word.length > width) {
        if (current.isNotEmpty) {
          out.add(current);
          current = '';
        }
        out.add(word.substring(0, width));
        word = word.substring(width);
      }
      if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= width) {
        current = '$current $word';
      } else {
        out.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty || out.isEmpty) out.add(current);
    return out;
  }

  static String _center(String s, int width) {
    if (s.length >= width) return s.substring(0, width);
    final left = (width - s.length) ~/ 2;
    return (' ' * left + s).padRight(width);
  }

  void _write(
    String text, {
    _Align align = _Align.left,
    bool bold = false,
    bool big = false,
  }) {
    final clean = sanitize(text);
    _bytes.addAll(switch (align) {
      _Align.left => EscPos.alignLeft,
      _Align.center => EscPos.alignCenter,
      _Align.right => EscPos.alignRight,
    });
    _bytes.addAll(bold ? EscPos.boldOn : EscPos.boldOff);
    _bytes.addAll(big ? EscPos.sizeDouble : EscPos.sizeNormal);
    _bytes.addAll(clean.codeUnits);
    _bytes.addAll(EscPos.lineFeed);
    // Always reset styles after the line so nothing leaks to the next one.
    if (bold) _bytes.addAll(EscPos.boldOff);
    if (big) _bytes.addAll(EscPos.sizeNormal);
    if (align != _Align.left) _bytes.addAll(EscPos.alignLeft);
    _lines.add(clean);
  }

  void blank() => _write('');

  void divider() => _write('-' * cols);

  /// Centered text, wrapped. Big text uses half the characters per line.
  void center(String text, {bool bold = false, bool big = false}) {
    final width = big ? cols ~/ 2 : cols;
    for (final part in wrap(text, width)) {
      _write(part, align: _Align.center, bold: bold, big: big);
    }
  }

  void left(String text, {bool bold = false}) {
    for (final part in wrap(text, cols)) {
      _write(part, bold: bold);
    }
  }

  /// "Label ............ Value" on one line, value right-aligned.
  void labelValue(String label, String value, {bool bold = false}) {
    final v = sanitize(value);
    final maxLabel = cols - v.length - 1;
    var l = sanitize(label);
    if (l.length > maxLabel) l = l.substring(0, maxLabel < 0 ? 0 : maxLabel);
    _write(l + ' ' * (cols - l.length - v.length) + v, bold: bold);
  }

  void itemHeader() {
    _write(_row('Item', 'Qty', 'Amount'), bold: false);
  }

  String _row(String name, String qty, String amount) {
    final g = ' ' * layout.gap;
    return sanitize(name).padRight(layout.nameW).substring(0, layout.nameW) +
        g +
        _center(sanitize(qty), layout.qtyW) +
        g +
        sanitize(amount).padLeft(layout.amountW);
  }

  /// One item: first line has name + qty + amount, long names wrap below.
  void item(String name, int qty, String amount, {String note = ''}) {
    final parts = wrap(name, layout.nameW);
    _write(_row(parts.first, '$qty', amount));
    for (final extra in parts.skip(1)) {
      _write(extra);
    }
    if (note.trim().isNotEmpty) {
      for (final n in wrap('  * ${note.trim()}', cols)) {
        _write(n);
      }
    }
  }

  /// Feed paper out, then cut. ZYWELL models with a cutter auto-cut;
  /// models without a cutter simply ignore the cut command.
  List<int> finish() {
    _bytes
      ..addAll(EscPos.feedLines(3))
      ..addAll(EscPos.cut);
    return List.unmodifiable(_bytes);
  }
}

/// Builds the full receipt for an order. Called ONCE per print.
({List<int> bytes, List<String> lines}) buildOrderReceipt(
  Order order,
  ReceiptSettings s,
) {
  final b = ReceiptBuilder(s.paperMm);
  String money(int cents) => formatMoney(cents, s.currency);

  // Header
  b.center(s.shopName.isEmpty ? 'My Cafe' : s.shopName, bold: true, big: true);
  if (s.shopPhone.trim().isNotEmpty) b.center(s.shopPhone);
  if (s.shopAddress.trim().isNotEmpty) b.center(s.shopAddress);
  b.blank();

  // Order info
  b.left('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(order.createdAt)}');
  b.labelValue('Order: ${order.number}', 'Cashier: ${order.cashier}');
  b.blank();

  // Items
  b.itemHeader();
  b.divider();
  for (final item in order.items) {
    b.item(item.name, item.qty, money(item.lineTotalCents), note: item.note);
  }
  b.divider();
  b.blank();

  // Totals (TOTAL is the only bold line besides the shop name)
  b.labelValue('Subtotal', money(order.subtotalCents));
  b.labelValue('TOTAL', money(order.totalCents), bold: true);
  b.labelValue('Payment:', order.paymentMethod);
  if (order.cashGivenCents != null) {
    b.labelValue('Cash Given:', money(order.cashGivenCents!));
    b.labelValue('Change:', money(order.changeCents));
  }
  b.blank();

  // Footer
  b.center(s.footer);

  return (bytes: b.finish(), lines: b.lines);
}

/// Builds the test receipt.
({List<int> bytes, List<String> lines}) buildTestReceipt(ReceiptSettings s) {
  final b = ReceiptBuilder(s.paperMm);
  b.center('ZYWELL TEST - SUCCESS', bold: true);
  b.blank();
  b.left('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}');
  b.left('Paper: ${s.paperMm}mm (${b.cols} chars per line)');
  b.blank();
  b.left(
    '1234567890' * (b.cols ~/ 10) + '1234567890'.substring(0, b.cols % 10),
  );
  b.labelValue('Left', 'Right');
  b.labelValue('Total:', formatMoney(1400, s.currency));
  b.blank();
  b.center('If this line is centered,');
  b.center('Receipt Mode is OK');
  return (bytes: b.finish(), lines: b.lines);
}

// ============================================================================
// The service
// ============================================================================

class ZywellPrinterService {
  ZywellPrinterService._();
  static final ZywellPrinterService instance = ZywellPrinterService._();

  static const _prefsKey = 'default_printer';

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  PrinterStatus _status = PrinterStatus.disconnected;
  PrinterDevice? _device;
  final _statusController = StreamController<PrinterStatus>.broadcast();
  final _disconnectWarnings = StreamController<String>.broadcast();

  // BLE connection state
  StreamSubscription<ConnectionStateUpdate>? _bleConnection;
  Characteristic? _bleWriteChar;
  int _bleMtu = 23;

  // Classic connection watchdog
  Timer? _classicWatchdog;
  bool _userDisconnect = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  PrinterDevice? get currentDevice => _device;
  Stream<PrinterStatus> get statusStream => _statusController.stream;

  /// Emits a warning when the ZYWELL drops unexpectedly (often low battery).
  Stream<String> get disconnectWarnings => _disconnectWarnings.stream;

  /// Connected / Disconnected / Printing / Error / Paper Out
  PrinterStatus getStatus() => _status;

  void _setStatus(PrinterStatus s) {
    if (_status == s) return;
    _status = s;
    _statusController.add(s);
  }

  // ---------------------------------------------------------------- Bluetooth

  /// True if Bluetooth is ON. If false, the screen should show
  /// [ZywellMessages.bluetoothOffPopup].
  Future<bool> checkBluetoothOn() async {
    try {
      if (_isAndroid) {
        return await PrintBluetoothThermal.bluetoothEnabled;
      }
      // iOS reports "unknown" for a moment at start-up, so wait for a real value.
      final status = await _ble.statusStream
          .where((s) => s != BleStatus.unknown)
          .first
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => BleStatus.unknown,
          );
      // "unauthorized" means Bluetooth is on but permission is not given yet.
      return status == BleStatus.ready || status == BleStatus.unauthorized;
    } catch (_) {
      return false;
    }
  }

  /// Asks for Bluetooth Scan, Bluetooth Connect and Location (Android needs
  /// Location to scan). Explain to the user first: [ZywellMessages.permissionsWhy].
  Future<bool> requestPermissions() async {
    try {
      if (_isAndroid) {
        final results = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();
        final scan = results[Permission.bluetoothScan]!;
        final connect = results[Permission.bluetoothConnect]!;
        final location = results[Permission.locationWhenInUse]!;
        // Android 12+ needs scan+connect. Android 11 and older need location.
        return (scan.isGranted && connect.isGranted) || location.isGranted;
      }
      final bt = await Permission.bluetooth.request();
      return bt.isGranted || bt.isLimited;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------------- Scan

  /// Scans for 10 seconds and emits the growing list of devices (Name + MAC).
  /// Shows ALL devices, it does not filter by name, because ZYWELL printers
  /// appear as ZY306, ZYWELL, ZM01, ZM04, Printer_xxxx, etc.
  ///
  /// On Android the list includes printers already paired with the phone
  /// (Bluetooth Classic, best for ZYWELL) plus nearby BLE printers.
  Stream<List<PrinterDevice>> scanDevices({
    Duration timeout = const Duration(seconds: 10),
  }) {
    final controller = StreamController<List<PrinterDevice>>();
    final found = <String, PrinterDevice>{};
    StreamSubscription<DiscoveredDevice>? sub;
    Timer? timer;

    void emit() {
      final list = found.values.toList()
        ..sort((a, b) {
          // Likely printers first, then by name.
          final ap = looksLikePrinter(a.name) ? 0 : 1;
          final bp = looksLikePrinter(b.name) ? 0 : 1;
          if (ap != bp) return ap - bp;
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        });
      if (!controller.isClosed) controller.add(list);
    }

    Future<void> finish() async {
      timer?.cancel();
      await sub?.cancel();
      sub = null;
      emit();
      if (!controller.isClosed) await controller.close();
    }

    Future<void> run() async {
      try {
        if (_isAndroid) {
          final paired = await PrintBluetoothThermal.pairedBluetooths;
          for (final p in paired) {
            found['c:${p.macAdress}'] = PrinterDevice(
              name: p.name,
              address: p.macAdress,
              link: PrinterLink.classic,
            );
          }
          emit();
        }
        sub = _ble
            .scanForDevices(
              withServices: const [],
              scanMode: ScanMode.lowLatency,
              requireLocationServicesEnabled: false,
            )
            .listen((d) {
              // Skip nameless BLE beacons; they are almost never printers.
              if (d.name.trim().isEmpty) return;
              // If the same printer is already listed as paired Classic, keep that.
              if (found.containsKey('c:${d.id}')) return;
              found['b:${d.id}'] = PrinterDevice(
                name: d.name,
                address: d.id,
                link: PrinterLink.ble,
              );
              emit();
            }, onError: (_) => finish());
        timer = Timer(timeout, finish);
      } catch (_) {
        await finish();
      }
    }

    controller.onCancel = finish;
    run();
    return controller.stream;
  }

  static bool looksLikePrinter(String name) {
    final n = name.toUpperCase();
    return n.startsWith('ZY') ||
        n.contains('ZYWELL') ||
        n.startsWith('ZM') ||
        n.contains('PRINT') ||
        n.contains('POS') ||
        n.startsWith('MPT') ||
        n.startsWith('RPP');
  }

  // ------------------------------------------------------------------ Connect

  /// Connects and saves it as the Default Printer. Returns a friendly message
  /// on failure, or null on success.
  Future<String?> connect(PrinterDevice device) async {
    if (!await checkBluetoothOn()) return ZywellMessages.bluetoothOff;
    await _disconnectQuietly();
    _userDisconnect = false;
    _setStatus(PrinterStatus.connecting);
    try {
      final ok = device.link == PrinterLink.classic
          ? await _connectClassic(device)
          : await _connectBle(device);
      if (!ok) {
        await _disconnectQuietly();
        _setStatus(PrinterStatus.disconnected);
        return ZywellMessages.connectFailed;
      }
      _device = device;
      await _saveDefault(device);
      _setStatus(PrinterStatus.connected);
      return null;
    } catch (_) {
      await _disconnectQuietly();
      _setStatus(PrinterStatus.disconnected);
      return ZywellMessages.connectFailed;
    }
  }

  Future<bool> _connectClassic(PrinterDevice device) async {
    // On Android, connecting to an unpaired printer makes Android show its
    // pairing dialog right here in the app (PIN usually 0000).
    final ok = await PrintBluetoothThermal.connect(
      macPrinterAddress: device.address,
    ).timeout(const Duration(seconds: 20), onTimeout: () => false);
    if (!ok) return false;
    _classicWatchdog?.cancel();
    _classicWatchdog = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_status == PrinterStatus.printing) return;
      bool alive;
      try {
        alive = await PrintBluetoothThermal.connectionStatus;
      } catch (_) {
        alive = false;
      }
      if (!alive) _onUnexpectedDisconnect();
    });
    return true;
  }

  Future<bool> _connectBle(PrinterDevice device) async {
    final connected = Completer<bool>();
    _bleConnection = _ble
        .connectToDevice(
          id: device.address,
          connectionTimeout: const Duration(seconds: 15),
        )
        .listen(
          (update) {
            switch (update.connectionState) {
              case DeviceConnectionState.connected:
                if (!connected.isCompleted) connected.complete(true);
              case DeviceConnectionState.disconnected:
                if (!connected.isCompleted) {
                  connected.complete(false);
                } else {
                  _onUnexpectedDisconnect();
                }
              default:
                break;
            }
          },
          onError: (_) {
            if (!connected.isCompleted) {
              connected.complete(false);
            } else {
              _onUnexpectedDisconnect();
            }
          },
        );

    if (!await connected.future) return false;

    _bleMtu = 23;
    if (_isAndroid) {
      try {
        _bleMtu = await _ble.requestMtu(deviceId: device.address, mtu: 185);
      } catch (_) {}
    }

    final services = await _ble.getDiscoveredServices(device.address);
    Characteristic? best;
    for (final s in services) {
      final uuid = s.id.toString().toLowerCase();
      // Common thermal-printer service UUIDs.
      final isPrinterService =
          uuid.contains('18f0') ||
          uuid.startsWith('e7810a71') ||
          uuid.startsWith('49535343') ||
          uuid.contains('ff00') ||
          uuid.contains('ae30');
      for (final c in s.characteristics) {
        if (!(c.isWritableWithoutResponse || c.isWritableWithResponse)) {
          continue;
        }
        if (best == null || isPrinterService) best = c;
        if (isPrinterService) break;
      }
      if (isPrinterService && best != null) break;
    }
    _bleWriteChar = best;
    return best != null;
  }

  void _onUnexpectedDisconnect() {
    if (_userDisconnect) return;
    if (_status == PrinterStatus.disconnected) return;
    _classicWatchdog?.cancel();
    _bleWriteChar = null;
    _setStatus(PrinterStatus.disconnected);
    _disconnectWarnings.add(ZywellMessages.disconnectedWarning);
  }

  /// On app start, try to reconnect to the last saved ZYWELL automatically.
  Future<bool> autoReconnect() async {
    final saved = await loadDefault();
    if (saved == null) return false;
    _device = saved;
    if (!await checkBluetoothOn()) return false;
    final error = await connect(saved);
    return error == null;
  }

  /// Disconnects. If [forget] is true, also removes the Default Printer.
  Future<void> disconnect({bool forget = false}) async {
    _userDisconnect = true;
    await _disconnectQuietly();
    _setStatus(PrinterStatus.disconnected);
    if (forget) {
      _device = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    }
  }

  Future<void> _disconnectQuietly() async {
    _classicWatchdog?.cancel();
    _classicWatchdog = null;
    // Cancelling the BLE subscription disconnects the BLE link.
    await _bleConnection?.cancel();
    _bleConnection = null;
    _bleWriteChar = null;
    if (_isAndroid) {
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
    }
  }

  Future<void> _saveDefault(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, device.toJson());
  }

  Future<PrinterDevice?> loadDefault() async {
    final prefs = await SharedPreferences.getInstance();
    return PrinterDevice.fromJson(prefs.getString(_prefsKey));
  }

  // -------------------------------------------------------------------- Print

  /// Builds the receipt bytes ONCE, then sends them (once per copy).
  Future<PrintResult> printReceipt(
    Order order,
    ReceiptSettings settings, {
    int copies = 1,
  }) {
    final receipt = buildOrderReceipt(order, settings);
    return _send(receipt.bytes, copies: copies);
  }

  /// Prints "ZYWELL TEST - SUCCESS" + date + paper size.
  Future<PrintResult> printTestReceipt(ReceiptSettings settings) {
    return _send(buildTestReceipt(settings).bytes);
  }

  Future<bool> _isConnected() async {
    if (_device == null) return false;
    if (_device!.link == PrinterLink.classic) {
      try {
        return await PrintBluetoothThermal.connectionStatus;
      } catch (_) {
        return false;
      }
    }
    return _bleWriteChar != null && _status != PrinterStatus.disconnected;
  }

  Future<PrintResult> _send(List<int> bytes, {int copies = 1}) async {
    if (_status == PrinterStatus.printing) {
      return const PrintResult(false, 'Already printing, please wait');
    }
    if (!await checkBluetoothOn()) {
      return const PrintResult(false, ZywellMessages.bluetoothOff);
    }
    if (!await _isConnected()) {
      _setStatus(PrinterStatus.disconnected);
      return PrintResult(
        false,
        _device == null
            ? ZywellMessages.notConnected
            : ZywellMessages.disconnectedMidPrint,
      );
    }
    _setStatus(PrinterStatus.printing);
    try {
      for (var i = 0; i < copies; i++) {
        final ok = _device!.link == PrinterLink.classic
            ? await PrintBluetoothThermal.writeBytes(bytes)
            : await _writeBle(bytes);
        if (!ok) {
          _setStatus(
            await _isConnected()
                ? PrinterStatus.error
                : PrinterStatus.disconnected,
          );
          return const PrintResult(false, ZywellMessages.disconnectedMidPrint);
        }
      }
      _setStatus(PrinterStatus.connected);
      return const PrintResult(true, ZywellMessages.printOk);
    } catch (_) {
      _setStatus(
        await _isConnected() ? PrinterStatus.error : PrinterStatus.disconnected,
      );
      return const PrintResult(false, ZywellMessages.disconnectedMidPrint);
    }
  }

  Future<bool> _writeBle(List<int> bytes) async {
    final c = _bleWriteChar;
    if (c == null) return false;
    final withResponse = !c.isWritableWithoutResponse;
    // Cheap printers have small buffers: send small chunks with a short pause.
    final chunk = (_bleMtu - 3).clamp(20, 180);
    for (var i = 0; i < bytes.length; i += chunk) {
      final end = (i + chunk < bytes.length) ? i + chunk : bytes.length;
      await c.write(bytes.sublist(i, end), withResponse: withResponse);
      if (!withResponse) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    return true;
  }
}
