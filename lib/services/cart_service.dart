import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class CartService {
  static String get baseUrl => ApiConfig.endpoint("cart");
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> cartUnreadNotifier = ValueNotifier<bool>(
    false,
  );

  static String _localCartKey(int userId) => 'local_cart_$userId';

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

  static Future<int> getCartCount(int userId) async {
    if (userId <= 0) return 0;

    final remote = await getCart(userId);
    final local = await getLocalCart(userId);
    final remoteItems = remote['data'] is List ? (remote['data'] as List) : [];
    final localItems = local['data'] is List ? (local['data'] as List) : [];
    final remoteCount = _totalQuantity(remoteItems);
    final localCount = _totalQuantity(localItems);

    return localCount > remoteCount ? localCount : remoteCount;
  }

  static Future<void> refreshCartCount(int userId) async {
    final total = await getCartCount(userId);
    cartCountNotifier.value = total;
  }

  static Future<void> refreshCartCountForCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('id') ?? 0;
    await refreshCartCount(userId);
  }

  static void markCartUpdated() {
    cartUnreadNotifier.value = true;
  }

  static void markCartViewed() {
    cartUnreadNotifier.value = false;
  }

  static Future<Map<String, dynamic>> getResolvedCart(int userId) async {
    if (userId <= 0) {
      return {"status": true, "data": [], "total": 0, "source": "local"};
    }

    final remote = await getCart(userId);
    final local = await getLocalCart(userId);

    final remoteItems = remote['data'] is List ? (remote['data'] as List) : [];
    final localItems = local['data'] is List ? (local['data'] as List) : [];

    final remoteCount = _totalQuantity(remoteItems);
    final localCount = _totalQuantity(localItems);

    if (localCount > remoteCount && localItems.isNotEmpty) {
      final resolved = Map<String, dynamic>.from(local);
      resolved['source'] = 'local';
      return resolved;
    }

    if (remoteItems.isNotEmpty) {
      final resolved = Map<String, dynamic>.from(remote);
      resolved['source'] = 'server';
      return resolved;
    }

    if (localItems.isNotEmpty) {
      final resolved = Map<String, dynamic>.from(local);
      resolved['source'] = 'local';
      return resolved;
    }

    return {"status": true, "data": [], "total": 0, "source": "server"};
  }

  static Map<String, dynamic> _errorMessage(
    String message, {
    List<dynamic>? data,
    dynamic total,
  }) {
    return {"status": false, "message": message, "data": data, "total": total};
  }

  static Future<Map<String, dynamic>> _postWithFallback(
    String path,
    Map<String, dynamic> payload,
  ) async {
    http.Response response;

    try {
      response = await http
          .post(
            Uri.parse("$baseUrl/$path"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.timeout);
    } catch (_) {
      return _errorMessage("Network error");
    }

    // Many PHP backends read only $_POST and fail for raw JSON.
    if (response.statusCode >= 500) {
      try {
        response = await http
            .post(
              Uri.parse("$baseUrl/$path"),
              body: payload.map(
                (key, value) => MapEntry(key, value.toString()),
              ),
            )
            .timeout(ApiConfig.timeout);
      } catch (_) {
        return _errorMessage("Network error");
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _errorMessage("Server error (${response.statusCode})");
    }

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      return _errorMessage("Invalid server response");
    } catch (_) {
      return _errorMessage("Invalid server response");
    }
  }

  static Future<Map<String, dynamic>> getCart(int userId) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/get_cart.php?user_id=$userId"))
          .timeout(ApiConfig.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _errorMessage(
          "Server error (${response.statusCode})",
          data: [],
          total: 0,
        );
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        data['data'] = data['data'] is List ? data['data'] : [];
        data['total'] = data['total'] ?? 0;
        return data;
      }

      return _errorMessage("Invalid server response", data: [], total: 0);
    } catch (_) {
      return _errorMessage("Network error", data: [], total: 0);
    }
  }

  static Future<Map<String, dynamic>> checkout(
    int userId, {
    String paymentMethod = "cash",
  }) async {
    return _postWithFallback("checkout.php", {
      "user_id": userId,
      "payment_method": paymentMethod,
    });
  }

  static Future<Map<String, dynamic>> addToCart(
    int userId,
    int productId,
    int quantity,
  ) async {
    return _postWithFallback("add_to_cart.php", {
      "user_id": userId,
      "product_id": productId,
      "quantity": quantity,
    });
  }

  static Future<void> addLocalCartItem({
    required int userId,
    required int productId,
    required String name,
    required String image,
    required double price,
    int quantity = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _localCartKey(userId);

    final raw = prefs.getString(key);
    final List<dynamic> decoded = raw == null
        ? []
        : (jsonDecode(raw) as List<dynamic>);
    final items = decoded
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: true);

    final index = items.indexWhere(
      (item) => (item['product_id'] ?? 0).toString() == productId.toString(),
    );

    if (index >= 0) {
      final currentQty = int.tryParse(items[index]['quantity'].toString()) ?? 0;
      final newQty = currentQty + quantity;
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

    await prefs.setString(key, jsonEncode(items));
  }

  static Future<Map<String, dynamic>> getLocalCart(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _localCartKey(userId);
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) {
      return {"status": true, "data": [], "total": 0};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return {"status": true, "data": [], "total": 0};
      }

      final items = decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      double total = 0;
      for (final item in items) {
        final subtotal =
            double.tryParse((item['subtotal'] ?? '0').toString()) ??
            ((double.tryParse((item['price'] ?? '0').toString()) ?? 0) *
                (int.tryParse((item['quantity'] ?? '0').toString()) ?? 0));
        total += subtotal;
      }

      return {"status": true, "data": items, "total": total.toStringAsFixed(2)};
    } catch (_) {
      return {"status": true, "data": [], "total": 0};
    }
  }

  static Future<void> clearLocalCart(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localCartKey(userId));
  }

  static Future<void> removeLocalCartItem(int userId, int productId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _localCartKey(userId);
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final items = decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: true);

      items.removeWhere(
        (item) => (item['product_id'] ?? 0).toString() == productId.toString(),
      );

      await prefs.setString(key, jsonEncode(items));
    } catch (_) {
      // Ignore malformed local cache data.
    }
  }

  static Future<void> updateLocalCartItemQuantity(
    int userId,
    int productId,
    int quantity,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _localCartKey(userId);
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final items = decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: true);

      final index = items.indexWhere(
        (item) => (item['product_id'] ?? 0).toString() == productId.toString(),
      );
      if (index < 0) return;

      if (quantity <= 0) {
        items.removeAt(index);
      } else {
        final currentQty =
            int.tryParse((items[index]['quantity'] ?? 1).toString()) ?? 1;
        final subtotal =
            double.tryParse((items[index]['subtotal'] ?? '0').toString()) ?? 0;
        final fallbackPrice = subtotal / (currentQty <= 0 ? 1 : currentQty);
        final price =
            double.tryParse((items[index]['price'] ?? '0').toString()) ??
            fallbackPrice;

        items[index]['quantity'] = quantity;
        items[index]['price'] = price.toStringAsFixed(2);
        items[index]['subtotal'] = (price * quantity).toStringAsFixed(2);
      }

      await prefs.setString(key, jsonEncode(items));
    } catch (_) {
      // Ignore malformed local cache data.
    }
  }
}
