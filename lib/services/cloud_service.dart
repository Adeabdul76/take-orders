import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_config.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/shop_settings.dart';
import '../utils/image_tools.dart';
import 'data_repository.dart';
import 'database_service.dart';

/// Friendly messages for sharing problems.
class CloudMessages {
  static const notSetUp =
      'Sharing is not set up yet. Ask the person who set up the app to add '
      'the Firebase settings.';
  static const noInternet =
      'No internet. Joining or creating a shared cafe needs internet once. '
      'After that the app also works offline.';
  static const wrongCodeOrPin =
      'Wrong cafe code or PIN. Please check and try again.';
  static const failed = 'Something went wrong. Please try again.';
}

class CloudException implements Exception {
  final String message;
  const CloudException(this.message);
  @override
  String toString() => message;
}

/// Result of creating or joining a shared cafe.
class CafeMembership {
  final String cafeCode;
  final String deviceTag; // "A" for the first phone, "B", "C", ...
  final bool isOwner;
  const CafeMembership(this.cafeCode, this.deviceTag, this.isOwner);
}

/// Connects to Firebase and creates / joins a shared cafe.
///
/// Firestore layout:
///   cafes/{code}                 ownerUid, nextDevice, shop{...}
///   cafes/{code}/secret/pin      pin (nobody can read it)
///   cafes/{code}/members/{uid}   pin, tag, role
///   cafes/{code}/products/{id}
///   cafes/{code}/orders/{id}
class CloudService {
  CloudService._();
  static final CloudService instance = CloudService._();

  static const _codeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  bool _ready = false;
  bool get isConfigured => FirebaseConfig.isSet;

  Future<bool> init() async {
    if (_ready) return true;
    if (!FirebaseConfig.isSet) return false;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: FirebaseConfig.apiKey,
          appId: FirebaseConfig.appId,
          messagingSenderId: FirebaseConfig.messagingSenderId,
          projectId: FirebaseConfig.projectId,
        ),
      );
      // Keep a full copy on the phone so the app works without internet.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _ready = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
    return _ready;
  }

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> _cafe(String code) =>
      _fs.collection('cafes').doc(code);

  Future<String> _signIn() async {
    if (!await init()) throw const CloudException(CloudMessages.notSetUp);
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (user == null) throw const CloudException(CloudMessages.failed);
      return user.uid;
    } on FirebaseAuthException catch (e) {
      throw CloudException(
        e.code == 'network-request-failed'
            ? CloudMessages.noInternet
            : CloudMessages.failed,
      );
    }
  }

  static String tagFor(int n) =>
      n < 26 ? String.fromCharCode(65 + n) : 'P${n + 1}';

  String _newCode() {
    final r = Random.secure();
    return List.generate(
      6,
      (_) => _codeChars[r.nextInt(_codeChars.length)],
    ).join();
  }

  CloudException _friendly(Object e) {
    if (e is CloudException) return e;
    if (e is FirebaseException) {
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        return const CloudException(CloudMessages.wrongCodeOrPin);
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return const CloudException(CloudMessages.noInternet);
      }
    }
    if (e is TimeoutException) {
      return const CloudException(CloudMessages.noInternet);
    }
    return const CloudException(CloudMessages.failed);
  }

  /// Creates a new shared cafe and uploads everything on this phone
  /// (menu, photos, shop details, logo, past orders) so other phones don't
  /// have to type it again.
  Future<CafeMembership> createCafe({
    required String pin,
    required LocalRepository local,
    void Function(String step)? onProgress,
  }) async {
    try {
      final uid = await _signIn();
      onProgress?.call('Creating your cafe...');
      String? code;
      for (var attempt = 0; attempt < 5 && code == null; attempt++) {
        final candidate = _newCode();
        try {
          await _cafe(candidate)
              .set({
                'ownerUid': uid,
                'nextDevice': 1,
                'createdAt': DateTime.now().millisecondsSinceEpoch,
                'shop': ((await local.getShop()) ?? const ShopSettings())
                    .toMap(),
              })
              .timeout(const Duration(seconds: 20));
          code = candidate;
        } on FirebaseException catch (e) {
          // Code already taken by another cafe: try another one.
          if (e.code != 'permission-denied') rethrow;
        }
      }
      if (code == null) throw const CloudException(CloudMessages.failed);
      final cafe = _cafe(code);
      await cafe.collection('secret').doc('pin').set({'pin': pin});
      await cafe.collection('members').doc(uid).set({
        'pin': pin,
        'tag': 'A',
        'role': 'owner',
        'joinedAt': DateTime.now().millisecondsSinceEpoch,
      });

      onProgress?.call('Uploading your menu...');
      final idMap = <String, String>{};
      final products = await local.getAllProducts();
      var batch = _fs.batch();
      var ops = 0;
      Future<void> flushIfFull() async {
        if (++ops >= 400) {
          await batch.commit();
          batch = _fs.batch();
          ops = 0;
        }
      }

      for (final p in products) {
        final ref = cafe.collection('products').doc();
        if (p.id != null) idMap[p.id!] = ref.id;
        var imageData = p.imageData;
        if (imageData == null && p.imagePath != null) {
          final file = File(p.imagePath!);
          if (await file.exists()) {
            imageData = await compute(
              makeThumbnailBase64,
              await file.readAsBytes(),
            );
          }
        }
        batch.set(
          ref,
          Product(
            name: p.name,
            priceCents: p.priceCents,
            category: p.category,
            imageData: imageData,
            emoji: p.emoji,
            available: p.available,
          ).toCloud(),
        );
        await flushIfFull();
      }

      onProgress?.call('Uploading past orders...');
      for (final o in await local.getAllOrders()) {
        final ref = cafe.collection('orders').doc();
        final items = o.items
            .map(
              (i) => OrderItem(
                productId: idMap[i.productId],
                name: i.name,
                unitPriceCents: i.unitPriceCents,
                qty: i.qty,
                note: i.note,
              ),
            )
            .toList();
        batch.set(
          ref,
          Order(
            numberText: o.numberText,
            createdAt: o.createdAt,
            items: items,
            subtotalCents: o.subtotalCents,
            totalCents: o.totalCents,
            paymentMethod: o.paymentMethod,
            cashGivenCents: o.cashGivenCents,
            changeCents: o.changeCents,
            cashier: o.cashier,
          ).toCloud(),
        );
        await flushIfFull();
      }
      await batch.commit();
      return CafeMembership(code, 'A', true);
    } catch (e) {
      throw _friendly(e);
    }
  }

  /// Joins an existing cafe with its code and PIN.
  Future<CafeMembership> joinCafe({
    required String code,
    required String pin,
  }) async {
    final cafeCode = code.trim().toUpperCase().replaceAll(' ', '');
    try {
      final uid = await _signIn();
      final cafe = _cafe(cafeCode);
      final member = cafe.collection('members').doc(uid);
      // The security rules only allow this if the PIN is right.
      // (merge: a phone that joins again keeps its letter A/B/C...)
      await member
          .set({
            'pin': pin.trim(),
            'role': 'staff',
            'joinedAt': DateTime.now().millisecondsSinceEpoch,
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 20));

      final existing = await member.get();
      var tag = (existing.data()?['tag'] as String?) ?? '';
      if (tag.isEmpty) {
        tag = await _fs.runTransaction((txn) async {
          final snap = await txn.get(cafe);
          final n = (snap.data()?['nextDevice'] as num?)?.toInt() ?? 1;
          final t = tagFor(n);
          txn.update(cafe, {'nextDevice': n + 1});
          txn.update(member, {'tag': t});
          return t;
        });
      }
      return CafeMembership(cafeCode, tag, false);
    } catch (e) {
      throw _friendly(e);
    }
  }

  /// The PIN of this cafe (for the owner to give to staff).
  Future<String?> readPin(String code) async {
    try {
      final uid = await _signIn();
      final snap = await _cafe(code).collection('members').doc(uid).get();
      return snap.data()?['pin'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// "Shared cafe" storage: Firebase Firestore, with a full offline copy on the
/// phone. Saving never waits for the internet: changes are stored on the phone
/// at once and sent when the phone is online again.
class CloudRepository implements DataRepository {
  final String cafeCode;
  CloudRepository(this.cafeCode);

  DocumentReference<Map<String, dynamic>> get _cafe =>
      FirebaseFirestore.instance.collection('cafes').doc(cafeCode);
  CollectionReference<Map<String, dynamic>> get _products =>
      _cafe.collection('products');
  CollectionReference<Map<String, dynamic>> get _orders =>
      _cafe.collection('orders');

  void _background(Future<void> f) {
    unawaited(f.catchError((Object e) => debugPrint('Cloud save failed: $e')));
  }

  static List<Product> _sorted(List<Product> list) => list
    ..sort((a, b) {
      final c = a.category.toLowerCase().compareTo(b.category.toLowerCase());
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  @override
  Stream<List<Product>> watchProducts() => _products.snapshots().map(
    (s) =>
        _sorted(s.docs.map((d) => Product.fromCloud(d.id, d.data())).toList()),
  );

  @override
  Future<List<Product>> getAllProducts() async {
    final s = await _products.get();
    return _sorted(
      s.docs.map((d) => Product.fromCloud(d.id, d.data())).toList(),
    );
  }

  @override
  Future<void> saveProduct(Product product) async {
    final ref = product.id == null
        ? _products.doc()
        : _products.doc(product.id);
    _background(ref.set(product.toCloud()));
  }

  @override
  Future<void> deleteProduct(String id) async {
    _background(_products.doc(id).delete());
  }

  Query<Map<String, dynamic>> _ordersQuery({DateTime? from, DateTime? to}) {
    Query<Map<String, dynamic>> q = _orders;
    if (from != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: from.millisecondsSinceEpoch,
      );
    }
    if (to != null) {
      q = q.where('createdAt', isLessThan: to.millisecondsSinceEpoch);
    }
    return q.orderBy('createdAt', descending: true);
  }

  @override
  Stream<List<Order>> watchOrders({required DateTime from, DateTime? to}) =>
      _ordersQuery(from: from, to: to).snapshots().map(
        (s) => s.docs.map((d) => Order.fromCloud(d.id, d.data())).toList(),
      );

  @override
  Future<List<Order>> getAllOrders() async {
    final s = await _ordersQuery().get();
    return s.docs.map((d) => Order.fromCloud(d.id, d.data())).toList();
  }

  @override
  Future<Order> addOrder(Order order) async {
    final ref = _orders.doc();
    _background(ref.set(order.toCloud()));
    return order.withId(ref.id);
  }

  @override
  Stream<ShopSettings?> watchShop() => _cafe.snapshots().map((s) {
    final shop = s.data()?['shop'];
    return shop is Map
        ? ShopSettings.fromMap(Map<String, dynamic>.from(shop))
        : null;
  });

  @override
  Future<ShopSettings?> getShop() async {
    final shop = (await _cafe.get()).data()?['shop'];
    return shop is Map
        ? ShopSettings.fromMap(Map<String, dynamic>.from(shop))
        : null;
  }

  @override
  Future<void> saveShop(ShopSettings shop) async {
    _background(_cafe.update({'shop': shop.toMap()}));
  }
}
