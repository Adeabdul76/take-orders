import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';

/// All saved data lives on the phone (offline-first). Nothing is sent online.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    return _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'take_orders.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            price_cents INTEGER NOT NULL,
            category TEXT NOT NULL DEFAULT '',
            image_path TEXT,
            emoji TEXT,
            available INTEGER NOT NULL DEFAULT 1
          )''');
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
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
    );
  }

  // ---------- Products ----------

  Future<List<Product>> getProducts() async {
    final rows = await (await db).query(
      'products',
      orderBy: 'category COLLATE NOCASE, name COLLATE NOCASE',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product> insertProduct(Product product) async {
    final map = product.toMap()..remove('id');
    final id = await (await db).insert('products', map);
    return product.copyWith(id: id);
  }

  Future<void> updateProduct(Product product) async {
    await (await db).update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(int id) async {
    await (await db).delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Orders ----------

  /// Saves the order and its item snapshots in one transaction.
  Future<Order> insertOrder(Order order) async {
    final database = await db;
    late int orderId;
    await database.transaction((txn) async {
      orderId = await txn.insert('orders', order.toMap());
      for (final item in order.items) {
        await txn.insert('order_items', item.toMap(orderId));
      }
    });
    return order.withId(orderId);
  }

  Future<List<Order>> getOrders({DateTime? from, DateTime? to}) async {
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
      orderBy: 'id DESC',
    );
    final orders = <Order>[];
    for (final row in rows) {
      final itemRows = await database.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [row['id']],
        orderBy: 'id',
      );
      orders.add(Order.fromMap(row, itemRows.map(OrderItem.fromMap).toList()));
    }
    return orders;
  }

  /// Total sales (in cents) and order count for today.
  Future<({int totalCents, int count})> getTodaySales() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (await db).rawQuery(
      'SELECT COALESCE(SUM(total_cents), 0) AS total, COUNT(*) AS n '
      'FROM orders WHERE created_at >= ? AND created_at < ?',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return (
      totalCents: (rows.first['total'] as int?) ?? 0,
      count: (rows.first['n'] as int?) ?? 0,
    );
  }
}
