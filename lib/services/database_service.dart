import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/shop_settings.dart';
import 'data_repository.dart';

/// "This phone only" storage: SQLite on the phone, works fully offline.
class LocalRepository implements DataRepository {
  LocalRepository._();
  static final LocalRepository instance = LocalRepository._();

  Database? _db;
  final _changes = StreamController<void>.broadcast();

  void _changed() => _changes.add(null);

  Future<Database> get db async {
    return _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'take_orders.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            price_cents INTEGER NOT NULL,
            category TEXT NOT NULL DEFAULT '',
            image_path TEXT,
            image_data TEXT,
            emoji TEXT,
            available INTEGER NOT NULL DEFAULT 1
          )''');
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number TEXT,
            created_at INTEGER NOT NULL,
            subtotal_cents INTEGER NOT NULL,
            total_cents INTEGER NOT NULL,
            payment_method TEXT NOT NULL,
            cash_given_cents INTEGER,
            change_cents INTEGER NOT NULL DEFAULT 0,
            cashier TEXT NOT NULL DEFAULT 'Owner'
          )''');
        await db.execute('''
          CREATE TABLE order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            product_id INTEGER,
            name TEXT NOT NULL,
            unit_price_cents INTEGER NOT NULL,
            qty INTEGER NOT NULL,
            note TEXT NOT NULL DEFAULT ''
          )''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Version 2: shareable product photos + order numbers like "A001".
          await db.execute('ALTER TABLE products ADD COLUMN image_data TEXT');
          await db.execute('ALTER TABLE orders ADD COLUMN number TEXT');
        }
      },
    );
  }

  Stream<T> _watch<T>(Future<T> Function() query) async* {
    yield await query();
    await for (final _ in _changes.stream) {
      yield await query();
    }
  }

  // ---------- Products ----------

  @override
  Stream<List<Product>> watchProducts() => _watch(getAllProducts);

  @override
  Future<List<Product>> getAllProducts() async {
    final rows = await (await db).query(
      'products',
      orderBy: 'category COLLATE NOCASE, name COLLATE NOCASE',
    );
    return rows
        .map(
          (m) => Product(
            id: '${m['id']}',
            name: m['name'] as String,
            priceCents: m['price_cents'] as int,
            category: (m['category'] as String?) ?? '',
            imagePath: m['image_path'] as String?,
            imageData: m['image_data'] as String?,
            emoji: m['emoji'] as String?,
            available: (m['available'] as int? ?? 1) == 1,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveProduct(Product product) async {
    final map = {
      'name': product.name,
      'price_cents': product.priceCents,
      'category': product.category,
      'image_path': product.imagePath,
      'image_data': product.imageData,
      'emoji': product.emoji,
      'available': product.available ? 1 : 0,
    };
    final database = await db;
    if (product.id == null) {
      await database.insert('products', map);
    } else {
      await database.update(
        'products',
        map,
        where: 'id = ?',
        whereArgs: [int.parse(product.id!)],
      );
    }
    _changed();
  }

  @override
  Future<void> deleteProduct(String id) async {
    await (await db).delete(
      'products',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
    _changed();
  }

  // ---------- Orders ----------

  @override
  Future<Order> addOrder(Order order) async {
    final database = await db;
    late int orderId;
    await database.transaction((txn) async {
      orderId = await txn.insert('orders', {
        'number': order.numberText,
        'created_at': order.createdAt.millisecondsSinceEpoch,
        'subtotal_cents': order.subtotalCents,
        'total_cents': order.totalCents,
        'payment_method': order.paymentMethod,
        'cash_given_cents': order.cashGivenCents,
        'change_cents': order.changeCents,
        'cashier': order.cashier,
      });
      for (final item in order.items) {
        await txn.insert('order_items', {
          'order_id': orderId,
          'product_id': int.tryParse(item.productId ?? ''),
          'name': item.name,
          'unit_price_cents': item.unitPriceCents,
          'qty': item.qty,
          'note': item.note,
        });
      }
    });
    _changed();
    return order.withId('$orderId');
  }

  Future<List<Order>> _queryOrders({DateTime? from, DateTime? to}) async {
    final database = await db;
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('created_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await database.query(
      'orders',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC, id DESC',
    );
    final orders = <Order>[];
    for (final row in rows) {
      final itemRows = await database.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [row['id']],
        orderBy: 'id',
      );
      final id = row['id'] as int;
      orders.add(
        Order(
          id: '$id',
          // Orders from before version 2 have no number: use the old "#001".
          numberText:
              (row['number'] as String?) ?? id.toString().padLeft(3, '0'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
          items: itemRows
              .map(
                (m) => OrderItem(
                  productId: m['product_id']?.toString(),
                  name: m['name'] as String,
                  unitPriceCents: m['unit_price_cents'] as int,
                  qty: m['qty'] as int,
                  note: (m['note'] as String?) ?? '',
                ),
              )
              .toList(),
          subtotalCents: row['subtotal_cents'] as int,
          totalCents: row['total_cents'] as int,
          paymentMethod: row['payment_method'] as String,
          cashGivenCents: row['cash_given_cents'] as int?,
          changeCents: (row['change_cents'] as int?) ?? 0,
          cashier: (row['cashier'] as String?) ?? 'Owner',
        ),
      );
    }
    return orders;
  }

  @override
  Stream<List<Order>> watchOrders({required DateTime from, DateTime? to}) =>
      _watch(() => _queryOrders(from: from, to: to));

  @override
  Future<List<Order>> getAllOrders() => _queryOrders();

  /// Highest old-style order id, so new order numbers carry on from it.
  Future<int> maxOrderId() async {
    final rows = await (await db).rawQuery(
      'SELECT COALESCE(MAX(id), 0) AS m FROM orders',
    );
    return (rows.first['m'] as int?) ?? 0;
  }

  // ---------- Shop details (saved in phone settings) ----------

  @override
  Stream<ShopSettings?> watchShop() => _watch(getShop);

  @override
  Future<ShopSettings?> getShop() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString('shop_name');
    if (name == null) return null;
    return ShopSettings(
      name: name,
      phone: p.getString('shop_phone') ?? '',
      address: p.getString('shop_address') ?? '',
      currency: p.getString('currency') ?? 'RM',
      footer: p.getString('footer') ?? 'Thank you! Come again!',
      logoPng: p.getString('shop_logo'),
    );
  }

  @override
  Future<void> saveShop(ShopSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('shop_name', s.name);
    await p.setString('shop_phone', s.phone);
    await p.setString('shop_address', s.address);
    await p.setString('currency', s.currency);
    await p.setString('footer', s.footer);
    if (s.logoPng == null) {
      await p.remove('shop_logo');
    } else {
      await p.setString('shop_logo', s.logoPng!);
    }
    _changed();
  }
}
