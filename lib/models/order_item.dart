/// One line on an order. Name and price are a SNAPSHOT taken at checkout,
/// so editing a product's price later never changes old orders.
class OrderItem {
  final int? id;
  final int? orderId;
  final int? productId;
  final String name;
  final int unitPriceCents;
  final int qty;
  final String note;

  const OrderItem({
    this.id,
    this.orderId,
    this.productId,
    required this.name,
    required this.unitPriceCents,
    required this.qty,
    this.note = '',
  });

  int get lineTotalCents => unitPriceCents * qty;

  Map<String, Object?> toMap(int orderId) => {
    'order_id': orderId,
    'product_id': productId,
    'name': name,
    'unit_price_cents': unitPriceCents,
    'qty': qty,
    'note': note,
  };

  factory OrderItem.fromMap(Map<String, Object?> m) => OrderItem(
    id: m['id'] as int?,
    orderId: m['order_id'] as int?,
    productId: m['product_id'] as int?,
    name: m['name'] as String,
    unitPriceCents: m['unit_price_cents'] as int,
    qty: m['qty'] as int,
    note: (m['note'] as String?) ?? '',
  );
}
