import 'order.dart';

class SummaryLine {
  final String label;
  int count;
  int cents;
  SummaryLine(this.label, {this.count = 0, this.cents = 0});
}

/// Totals for one day, worked out from that day's orders (all phones).
class DailySummary {
  final DateTime day;
  final int orderCount;
  final int totalCents;
  final List<SummaryLine> byPayment; // count = orders
  final List<SummaryLine> items; // count = qty sold, best sellers first
  final List<SummaryLine> byCashier; // count = orders
  final DateTime? firstOrder;
  final DateTime? lastOrder;

  const DailySummary({
    required this.day,
    required this.orderCount,
    required this.totalCents,
    required this.byPayment,
    required this.items,
    required this.byCashier,
    this.firstOrder,
    this.lastOrder,
  });

  int get averageCents =>
      orderCount == 0 ? 0 : (totalCents / orderCount).round();

  factory DailySummary.fromOrders(DateTime day, List<Order> orders) {
    final payment = <String, SummaryLine>{};
    final items = <String, SummaryLine>{};
    final cashier = <String, SummaryLine>{};
    var total = 0;
    DateTime? first, last;
    for (final o in orders) {
      total += o.totalCents;
      payment.putIfAbsent(o.paymentMethod, () => SummaryLine(o.paymentMethod))
        ..count += 1
        ..cents += o.totalCents;
      cashier.putIfAbsent(o.cashier, () => SummaryLine(o.cashier))
        ..count += 1
        ..cents += o.totalCents;
      for (final i in o.items) {
        items.putIfAbsent(i.name, () => SummaryLine(i.name))
          ..count += i.qty
          ..cents += i.lineTotalCents;
      }
      if (first == null || o.createdAt.isBefore(first)) first = o.createdAt;
      if (last == null || o.createdAt.isAfter(last)) last = o.createdAt;
    }
    int byCents(SummaryLine a, SummaryLine b) => b.cents.compareTo(a.cents);
    return DailySummary(
      day: DateTime(day.year, day.month, day.day),
      orderCount: orders.length,
      totalCents: total,
      byPayment: payment.values.toList()..sort(byCents),
      items: items.values.toList()
        ..sort(
          (a, b) =>
              b.count != a.count ? b.count.compareTo(a.count) : byCents(a, b),
        ),
      byCashier: cashier.values.toList()..sort(byCents),
      firstOrder: first,
      lastOrder: last,
    );
  }
}
