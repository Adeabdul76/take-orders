import 'dart:convert';

/// How the phone talks to the ZYWELL.
/// classic = Bluetooth Classic (SPP), the most reliable for ZYWELL on Android.
/// ble     = Bluetooth Low Energy, used on iOS and for unpaired printers.
enum PrinterLink { classic, ble }

class PrinterDevice {
  final String name;
  final String address; // MAC on Android, device id on iOS
  final PrinterLink link;

  const PrinterDevice({
    required this.name,
    required this.address,
    required this.link,
  });

  String get displayName => name.trim().isEmpty ? 'Unknown device' : name;

  String toJson() =>
      jsonEncode({'name': name, 'address': address, 'link': link.name});

  static PrinterDevice? fromJson(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return PrinterDevice(
        name: m['name'] as String? ?? '',
        address: m['address'] as String,
        link: PrinterLink.values.firstWhere(
          (l) => l.name == m['link'],
          orElse: () => PrinterLink.classic,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PrinterDevice && other.address == address && other.link == link;

  @override
  int get hashCode => Object.hash(address, link);
}
