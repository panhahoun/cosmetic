import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline mirror of the server cart plus the badge/unread notifiers.
/// Local-only; remote state lives in `cart_service_dio.dart`.
class CartCache {
  static String _key(int userId) => 'local_cart_$userId';

  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> cartUnreadNotifier =
      ValueNotifier<bool>(false);

  static int _itemQuantity(dynamic item) {
    if (item is Map) {
      return int.tryParse((item['quantity'] ?? 0).toString()) ?? 0;
    }
    return 0;
  }

  static int _totalQuantity(List<dynamic> items) {
    var total = 0;
    for (final item in items) {
      total += _itemQuantity(item);
    }
    return total;
  }

  static int countOf(List<dynamic> items) => _totalQuantity(items);

  static void markCartUpdated() => cartUnreadNotifier.value = true;

  static void markCartViewed() => cartUnreadNotifier.value = false;

  static Future<void> refreshCartCount(int userId) async {
    if (userId <= 0) {
      cartCountNotifier.value = 0;
      return;
    }
    final remote = await CartCacheRemoteBridge.itemsFor(userId);
    final local = await getLocalCart(userId);
    final remoteItems = remote['data'] is List ? (remote['data'] as List) : [];
    final localItems = local['data'] is List ? (local['data'] as List) : [];
    cartCountNotifier.value = _totalQuantity(localItems) > _totalQuantity(remoteItems)
        ? _totalQuantity(localItems)
        : _totalQuantity(remoteItems);
  }

  static Future<void> refreshCartCountForCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    await refreshCartCount(prefs.getInt('id') ?? 0);
  }

  /// Server cart wins, unless the local mirror holds more items.
  static Future<Map<String, dynamic>> resolve(int userId) async {
    if (userId <= 0) {
      return {'status': true, 'data': <dynamic>[], 'total': 0, 'source': 'local'};
    }

    final remote = await CartCacheRemoteBridge.itemsFor(userId);
    final local = await getLocalCart(userId);

    final remoteItems = remote['data'] is List ? (remote['data'] as List) : [];
    final localItems = local['data'] is List ? (local['data'] as List) : [];

    if (localItems.isNotEmpty && _totalQuantity(localItems) > _totalQuantity(remoteItems)) {
      return {...local, 'source': 'local'};
    }
    if (remoteItems.isNotEmpty) {
      return {...remote, 'source': 'server'};
    }
    if (localItems.isNotEmpty) {
      return {...local, 'source': 'local'};
    }
    return {'status': true, 'data': <dynamic>[], 'total': 0, 'source': 'server'};
  }

  static Future<List<Map<String, dynamic>>> _read(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: true);
    } catch (_) {
      // Corrupt cache is treated as empty.
      return [];
    }
  }

  static Future<void> _write(int userId, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(items));
  }

  static Future<void> addItem({
    required int userId,
    required int productId,
    required String name,
    required String image,
    required double price,
    int quantity = 1,
  }) async {
    if (userId <= 0) return;
    final items = await _read(userId);
    final index =
        items.indexWhere((i) => (i['product_id'] ?? 0).toString() == productId.toString());

    if (index >= 0) {
      final newQty = _itemQuantity(items[index]) + quantity;
      items[index]['quantity'] = newQty;
      items[index]['subtotal'] = (price * newQty).toStringAsFixed(2);
    } else {
      items.add({
        'product_id': productId,
        'name': name,
        'image': image,
        'price': price.toStringAsFixed(2),
        'quantity': quantity,
        'subtotal': (price * quantity).toStringAsFixed(2),
      });
    }
    await _write(userId, items);
  }

  /// `subtotal` is a string here and a float from the server.
  static Future<Map<String, dynamic>> getLocalCart(int userId) async {
    final items = await _read(userId);
    var total = 0.0;
    for (final item in items) {
      final subtotal = double.tryParse((item['subtotal'] ?? '0').toString()) ??
          (double.tryParse((item['price'] ?? '0').toString()) ?? 0) *
              _itemQuantity(item);
      total += subtotal;
    }
    return {'status': true, 'data': items, 'total': total.toStringAsFixed(2)};
  }

  static Future<void> clearLocalCart(int userId) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  static Future<void> removeItem(int userId, int productId) async {
    if (userId <= 0) return;
    final items = await _read(userId);
    items.removeWhere(
      (i) => (i['product_id'] ?? 0).toString() == productId.toString(),
    );
    await _write(userId, items);
  }

  static Future<void> updateQuantity(int userId, int productId, int quantity) async {
    if (userId <= 0) return;
    final items = await _read(userId);
    final index =
        items.indexWhere((i) => (i['product_id'] ?? 0).toString() == productId.toString());
    if (index < 0) return;

    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      final currentQty = _itemQuantity(items[index]) <= 0 ? 1 : _itemQuantity(items[index]);
      final subtotal = double.tryParse((items[index]['subtotal'] ?? '0').toString()) ?? 0;
      final price = double.tryParse((items[index]['price'] ?? '0').toString()) ??
          subtotal / currentQty;
      items[index]['quantity'] = quantity;
      items[index]['price'] = price.toStringAsFixed(2);
      items[index]['subtotal'] = (price * quantity).toStringAsFixed(2);
    }
    await _write(userId, items);
  }
}

/// Reads server-side quantities for the badge without depending on Dio.
abstract class CartCacheRemoteBridge {
  static Future<Map<String, dynamic>> Function(int userId)? itemsLoader;

  static Future<Map<String, dynamic>> itemsFor(int userId) async {
    final loader = itemsLoader;
    if (loader == null) return {'data': <dynamic>[]};
    try {
      return await loader(userId);
    } catch (_) {
      return {'data': <dynamic>[]};
    }
  }
}
