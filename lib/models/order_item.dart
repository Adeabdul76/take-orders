/// One line on an order. Name and price are a SNAPSHOT taken at checkout,
/// so editing a product's price later never changes old orders.
class OrderItem {
  final String? productId;
  final String name;
  final int unitPriceCents;
  final int qty;
  final String note;

  const OrderItem({
    this.productId,
    required this.name,
    required this.unitPriceCents,
    required this.qty,
    this.note = '',
  });

  int get lineTotalCents => unitPriceCents * qty;

  Map<String, Object?> toCloud() => {
    'productId': productId,
    'name': name,
    'unitPriceCents': unitPriceCents,
    'qty': qty,
    'note': note,
  };

  factory OrderItem.fromCloud(Map<String, dynamic> m) => OrderItem(
    productId: m['productId'] as String?,
    name: (m['name'] as String?) ?? '',
    unitPriceCents: (m['unitPriceCents'] as num?)?.toInt() ?? 0,
    qty: (m['qty'] as num?)?.toInt() ?? 1,
    note: (m['note'] as String?) ?? '',
  );
}
