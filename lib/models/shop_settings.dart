/// Shop details shared by every phone in the cafe (printed on receipts).
class ShopSettings {
  final String name;
  final String phone;
  final String address;
  final String currency; // "RM" or "MYR"
  final String footer;

  /// Receipt logo as base64 PNG (already trimmed and grey-scale), or null.
  final String? logoPng;

  const ShopSettings({
    this.name = '',
    this.phone = '',
    this.address = '',
    this.currency = 'RM',
    this.footer = 'Thank you! Come again!',
    this.logoPng,
  });

  ShopSettings copyWith({
    String? name,
    String? phone,
    String? address,
    String? currency,
    String? footer,
    String? logoPng,
    bool clearLogo = false,
  }) => ShopSettings(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    currency: currency ?? this.currency,
    footer: footer ?? this.footer,
    logoPng: clearLogo ? null : (logoPng ?? this.logoPng),
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'phone': phone,
    'address': address,
    'currency': currency,
    'footer': footer,
    'logoPng': logoPng,
  };

  factory ShopSettings.fromMap(Map<String, dynamic> m) => ShopSettings(
    name: (m['name'] as String?) ?? '',
    phone: (m['phone'] as String?) ?? '',
    address: (m['address'] as String?) ?? '',
    currency: (m['currency'] as String?) ?? 'RM',
    footer: (m['footer'] as String?) ?? 'Thank you! Come again!',
    logoPng: m['logoPng'] as String?,
  );
}
