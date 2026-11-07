import '../models/order.dart';
import '../models/product.dart';
import '../models/shop_settings.dart';

/// Where the cafe's data lives. Two versions:
/// - [LocalRepository] (database_service.dart): this phone only, SQLite.
/// - [CloudRepository] (cloud_service.dart): shared by all cafe phones, Firebase.
/// Screens and providers only talk to this interface, so they work the same
/// way in both modes.
abstract class DataRepository {
  /// Products, live: emits again whenever anything changes.
  Stream<List<Product>> watchProducts();

  /// Adds the product if it has no id yet, otherwise updates it.
  Future<void> saveProduct(Product product);
  Future<void> deleteProduct(String id);

  /// Orders created between [from] (inclusive) and [to] (exclusive), newest
  /// first, live.
  Stream<List<Order>> watchOrders({required DateTime from, DateTime? to});

  /// Saves the order and returns it with its id.
  Future<Order> addOrder(Order order);

  /// Shop details (name, logo, ...), live. Null until set up.
  Stream<ShopSettings?> watchShop();
  Future<void> saveShop(ShopSettings shop);

  /// Everything, once (used when moving this phone's data online).
  Future<List<Product>> getAllProducts();
  Future<List<Order>> getAllOrders();
  Future<ShopSettings?> getShop();
}
