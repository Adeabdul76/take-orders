import 'package:flutter_test/flutter_test.dart';
import 'package:take_orders/models/order.dart';
import 'package:take_orders/models/order_item.dart';
import 'package:take_orders/services/zywell_printer_service.dart';
import 'package:take_orders/utils/money.dart';

Order sampleOrder() => Order(
  id: 1,
  createdAt: DateTime(2026, 11, 6, 14, 30),
  items: const [
    OrderItem(name: 'Nasi Lemak', unitPriceCents: 800, qty: 1),
    OrderItem(name: 'Teh Tarik', unitPriceCents: 300, qty: 2),
  ],
  subtotalCents: 1400,
  totalCents: 1400,
  paymentMethod: 'Cash',
  cashGivenCents: 2000,
  changeCents: 600,
  cashier: 'Owner',
);

int count(List<String> lines, String needle) =>
    lines.where((l) => l.contains(needle)).length;

void main() {
  for (final paper in [80, 58]) {
    final cols = paper == 80 ? 48 : 32;

    group('${paper}mm receipt', () {
      final r = buildOrderReceipt(
        sampleOrder(),
        ReceiptSettings(
          shopName: 'Kopi BM',
          shopPhone: '012-345 6789',
          paperMm: paper,
        ),
      );

      test('every line fits in $cols characters', () {
        for (final line in r.lines) {
          expect(line.length, lessThanOrEqualTo(cols), reason: '"$line"');
        }
      });

      test('TOTAL appears ONCE, right-aligned on its own line', () {
        expect(count(r.lines, 'TOTAL'), 1);
        expect(count(r.lines, 'Subtotal'), 1);
        final total = r.lines.firstWhere((l) => l.startsWith('TOTAL'));
        expect(total.length, cols);
        expect(total.endsWith('RM 14.00'), isTrue);
      });

      test('items, payment and change print once', () {
        expect(count(r.lines, 'Nasi Lemak'), 1);
        expect(count(r.lines, 'Teh Tarik'), 1);
        expect(count(r.lines, 'Change:'), 1);
        expect(
          r.lines.any((l) => l.contains('RM 6.00') && l.contains('Teh Tarik')),
          isTrue,
        );
        expect(
          r.lines.any((l) => l.startsWith('Date: 06 Nov 2026 02:30 PM')),
          isTrue,
        );
        expect(
          r.lines.any(
            (l) => l.startsWith('Order: #001') && l.endsWith('Cashier: Owner'),
          ),
          isTrue,
        );
      });

      test('ends with 3 feed lines then the cut command', () {
        final tail = r.bytes.sublist(r.bytes.length - 6);
        expect(tail, [0x1B, 0x64, 3, 0x1D, 0x56, 0x00]);
      });

      test('no line contains a line feed in the middle', () {
        for (final line in r.lines) {
          expect(line.contains('\n'), isFalse);
        }
      });
    });
  }

  test('80mm item row uses 24 / 6 / 12 columns', () {
    final b = ReceiptBuilder(80)..item('Nasi Lemak', 1, 'RM 8.00');
    final line = b.lines.single;
    expect(line.length, 48);
    expect(line.substring(0, 24).trim(), 'Nasi Lemak');
    expect(line.substring(27, 33).trim(), '1');
    expect(line.substring(36), '     RM 8.00');
  });

  test('long names wrap instead of overlapping', () {
    final b = ReceiptBuilder(80)
      ..item('Mee Goreng Mamak Special Extra Pedas', 1, 'RM 9.50');
    expect(b.lines.length, 2);
    expect(b.lines.every((l) => l.length <= 48), isTrue);
  });

  test('non-ASCII characters are replaced safely', () {
    expect(ReceiptBuilder.sanitize('Café ☕'), 'Caf? ?');
  });

  test('money parsing', () {
    expect(parseMoneyToCents('8'), 800);
    expect(parseMoneyToCents('8.5'), 850);
    expect(parseMoneyToCents('RM 8.50'), 850);
    expect(parseMoneyToCents('abc'), isNull);
    expect(formatMoney(1400, 'MYR'), 'MYR 14.00');
  });
}
