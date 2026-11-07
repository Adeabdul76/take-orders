import 'order_item.dart';

class Order {
  final int? id;
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
    required this.createdAt,
    required this.items,
    required this.subtotalCents,
    required this.totalCents,
    required this.paymentMethod,
    this.cashGivenCents,
    this.changeCents = 0,
    this.cashier = 'Owner',
  });

  /// "#001", "#002" ... shown on screen and on the receipt.
  String get number => '#${(id ?? 0).toString().padLeft(3, '0')}';

  int get itemCount => items.fold(0, (sum, i) => sum + i.qty);

  Order withId(int newId) => Order(
    id: newId,
    createdAt: createdAt,
    items: items,
    subtotalCents: subtotalCents,
    totalCents: totalCents,
    paymentMethod: paymentMethod,
    cashGivenCents: cashGivenCents,
    changeCents: changeCents,
    cashier: cashier,
  );

  Map<String, Object?> toMap() => {
    'created_at': createdAt.millisecondsSinceEpoch,
    'subtotal_cents': subtotalCents,
    'total_cents': totalCents,
    'payment_method': paymentMethod,
    'cash_given_cents': cashGivenCents,
    'change_cents': changeCents,
    'cashier': cashier,
  };

  factory Order.fromMap(Map<String, Object?> m, List<OrderItem> items) => Order(
    id: m['id'] as int?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    items: items,
    subtotalCents: m['subtotal_cents'] as int,
    totalCents: m['total_cents'] as int,
    paymentMethod: m['payment_method'] as String,
    cashGivenCents: m['cash_given_cents'] as int?,
    changeCents: (m['change_cents'] as int?) ?? 0,
    cashier: (m['cashier'] as String?) ?? 'Owner',
  );
}
