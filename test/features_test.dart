import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:take_orders/models/daily_summary.dart';
import 'package:take_orders/models/order.dart';
import 'package:take_orders/models/order_item.dart';
import 'package:take_orders/models/product.dart';
import 'package:take_orders/services/zywell_printer_service.dart';
import 'package:take_orders/utils/image_tools.dart';

Order order(
  String n,
  int hour,
  String pay,
  List<OrderItem> items, {
  String cashier = 'Owner',
}) {
  final total = items.fold(0, (s, i) => s + i.lineTotalCents);
  return Order(
    numberText: n,
    createdAt: DateTime(2026, 11, 7, hour),
    items: items,
    subtotalCents: total,
    totalCents: total,
    paymentMethod: pay,
    cashier: cashier,
  );
}

const nasi = OrderItem(name: 'Nasi Lemak', unitPriceCents: 800, qty: 1);
const teh = OrderItem(name: 'Teh Tarik', unitPriceCents: 300, qty: 2);
const jollof = OrderItem(name: 'Jollof Rice', unitPriceCents: 1500, qty: 1);

void main() {
  final logoFile = File('test/fixtures/sample_logo.png');

  group('logo', () {
    test('is trimmed and printed at 320 dots on 80mm, 256 on 58mm', () {
      final prepared = prepareLogo(logoFile.readAsBytesSync())!;
      for (final mm in [80, 58]) {
        final s = ReceiptSettings(
          shopName: 'Ishola Cafe',
          paperMm: mm,
          logoPng: prepared,
        );
        final m = logoToMono(prepared, s.logoWidthDots);
        expect(m.width, mm == 80 ? 320 : 256);
        expect(m.height, greaterThan(100));
        // Some dots black, most white.
        final black = m.data.fold<int>(0, (a, b) => a + _bits(b));
        expect(black, greaterThan(m.width * m.height * 0.05));
        expect(black, lessThan(m.width * m.height * 0.6));
      }
    });

    test(
      'receipt starts with the logo as GS v 0 raster, shop name not repeated',
      () {
        final prepared = prepareLogo(logoFile.readAsBytesSync())!;
        final r = buildOrderReceipt(
          order('A001', 10, 'Cash', [nasi]),
          ReceiptSettings(
            shopName: 'Ishola Cafe',
            paperMm: 80,
            logoPng: prepared,
          ),
        );
        expect(r.lines.first, startsWith('[LOGO 320x'));
        expect(r.lines.any((l) => l.contains('Ishola Cafe')), isFalse);
        final idx = _indexOf(r.bytes, [0x1D, 0x76, 0x30, 0x00]);
        expect(idx, greaterThan(0));
        expect(r.bytes[idx + 4], 40); // 320 dots / 8 = 40 bytes per row
        expect(r.lines.where((l) => l.startsWith('TOTAL')).length, 1);
      },
    );

    test('without a logo the shop name prints as text', () {
      final r = buildOrderReceipt(
        order('001', 10, 'Cash', [nasi]),
        const ReceiptSettings(shopName: 'Ishola Cafe'),
      );
      expect(r.lines.first, 'Ishola Cafe');
      expect(_indexOf(r.bytes, [0x1D, 0x76, 0x30]), -1);
    });
  });

  group('daily summary', () {
    final orders = [
      order('A001', 9, 'Cash', [nasi, teh]),
      order('B001', 12, 'DuitNow QR', [jollof, teh], cashier: 'Aisha'),
      order('A002', 15, 'Cash', [jollof]),
    ];
    final d = DailySummary.fromOrders(DateTime(2026, 11, 7), orders);

    test('totals', () {
      expect(d.orderCount, 3);
      expect(d.totalCents, 1400 + 2100 + 1500);
      expect(d.averageCents, 1667);
      expect(d.byPayment.first.label, 'Cash');
      expect(d.byPayment.first.count, 2);
      expect(d.byPayment.first.cents, 2900);
      expect(d.items.first.label, 'Teh Tarik'); // 4 sold
      expect(d.items.first.count, 4);
      expect(d.byCashier.length, 2);
    });

    for (final mm in [80, 58]) {
      test(
        '${mm}mm summary receipt fits the paper and prints TOTAL SALES once',
        () {
          final r = buildDailySummaryReceipt(
            d,
            ReceiptSettings(shopName: 'Ishola Cafe', paperMm: mm),
          );
          final cols = mm == 80 ? 48 : 32;
          for (final l in r.lines) {
            expect(l.length, lessThanOrEqualTo(cols), reason: l);
          }
          expect(r.lines.where((l) => l.startsWith('TOTAL SALES')).length, 1);
          expect(r.lines.any((l) => l.contains('RM 50.00')), isTrue);
          expect(r.lines.any((l) => l.contains('DAILY SUMMARY')), isTrue);
          expect(r.bytes.sublist(r.bytes.length - 3), [0x1D, 0x56, 0x00]);
        },
      );
    }

    test('empty day', () {
      final e = DailySummary.fromOrders(DateTime(2026, 11, 8), const []);
      expect(e.orderCount, 0);
      expect(e.averageCents, 0);
      buildDailySummaryReceipt(e, const ReceiptSettings(shopName: 'X'));
    });
  });

  group('shared (cloud) format', () {
    test('order round-trips with its number and price snapshot', () {
      final o = order('B007', 13, 'Card', [
        const OrderItem(
          productId: 'p1',
          name: 'Suya',
          unitPriceCents: 1200,
          qty: 3,
          note: 'extra pepper',
        ),
      ]);
      final back = Order.fromCloud('id1', o.toCloud());
      expect(back.number, '#B007');
      expect(back.createdAt, o.createdAt);
      expect(back.items.single.lineTotalCents, 3600);
      expect(back.items.single.note, 'extra pepper');
    });

    test(
      'product round-trips and does not share the phone-only photo path',
      () {
        const p = Product(
          name: 'Puff Puff',
          priceCents: 500,
          category: 'Snacks',
          imagePath: '/data/x.jpg',
          imageData: 'abc',
          emoji: null,
        );
        final m = p.toCloud();
        expect(m.containsKey('imagePath'), isFalse);
        final back = Product.fromCloud('p9', m);
        expect(back.id, 'p9');
        expect(back.imageData, 'abc');
        expect(back.priceCents, 500);
      },
    );

    test('product photo thumbnail is small', () {
      final b64 = makeThumbnailBase64(logoFile.readAsBytesSync())!;
      expect(b64.length, lessThan(60 * 1024));
    });
  });
}

int _bits(int b) {
  var c = 0;
  for (var i = 0; i < 8; i++) {
    if (b & (1 << i) != 0) c++;
  }
  return c;
}

int _indexOf(List<int> hay, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
