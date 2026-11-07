import 'order_item.dart';

class Order {
  final String? id;

  /// Order number without "#", e.g. "001" (this phone only) or "A001"
  /// (shared cafe: A = first phone, B = second phone, ...).
  final String numberText;
  final DateTime createdAt;
  final List<OrderItem> items;
  final int subtotalCents;
  final int totalCents;
  final String paymentMethod;
  final int? cashGivenCents;
  final int changeCents;
  final String cashier;

  const Order({
    this.id,
    required this.numberText,
    required this.createdAt,
    required this.items,
    required this.subtotalCents,
    required this.totalCents,
    required this.paymentMethod,
    this.cashGivenCents,
    this.changeCents = 0,
    this.cashier = 'Owner',
  });

  /// "#001", "#A001" ... shown on screen and on the receipt.
  String get number => '#$numberText';

  int get itemCount => items.fold(0, (sum, i) => sum + i.qty);

  Order withId(String newId) => Order(
    id: newId,
    numberText: numberText,
    createdAt: createdAt,
    items: items,
    subtotalCents: subtotalCents,
    totalCents: totalCents,
    paymentMethod: paymentMethod,
    cashGivenCents: cashGivenCents,
    changeCents: changeCents,
    cashier: cashier,
  );

  /// Shared-online form (items are stored inside the order).
  Map<String, Object?> toCloud() => {
    'number': numberText,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'items': items.map((i) => i.toCloud()).toList(),
    'subtotalCents': subtotalCents,
    'totalCents': totalCents,
    'paymentMethod': paymentMethod,
    'cashGivenCents': cashGivenCents,
    'changeCents': changeCents,
    'cashier': cashier,
  };

  factory Order.fromCloud(String id, Map<String, dynamic> m) => Order(
    id: id,
    numberText: (m['number'] as String?) ?? '?',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (m['createdAt'] as num?)?.toInt() ?? 0,
    ),
    items: ((m['items'] as List?) ?? const [])
        .map((e) => OrderItem.fromCloud(Map<String, dynamic>.from(e as Map)))
        .toList(),
    subtotalCents: (m['subtotalCents'] as num?)?.toInt() ?? 0,
    totalCents: (m['totalCents'] as num?)?.toInt() ?? 0,
    paymentMethod: (m['paymentMethod'] as String?) ?? 'Cash',
    cashGivenCents: (m['cashGivenCents'] as num?)?.toInt(),
    changeCents: (m['changeCents'] as num?)?.toInt() ?? 0,
    cashier: (m['cashier'] as String?) ?? 'Owner',
  );
}
