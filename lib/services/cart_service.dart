import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class CartService {
  static String get baseUrl => ApiConfig.endpoint("cart");

  static String _localCartKey(int userId) => 'local_cart_$userId';

  static Map<String, dynamic> _errorMessage(
    String message, {
    List<dynamic>? data,
    dynamic total,
  }) {
    return {
      "status": false,
      "message": message,
      "data": data,
      "total": total,
    };
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
      final response = await http.get(
          Uri.parse("$baseUrl/get_cart.php?user_id=$userId")).timeout(ApiConfig.timeout);

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

  static Future<Map<String, dynamic>> checkout(int userId) async {
    return _postWithFallback(
      "checkout.php",
      {"user_id": userId, "payment_method": "cash"},
    );
  }

  static Future<Map<String, dynamic>> addToCart(
      int userId, int productId, int quantity) async {
    return _postWithFallback(
      "add_to_cart.php",
      {
        "user_id": userId,
        "product_id": productId,
        "quantity": quantity,
      },
    );
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
    final List<dynamic> decoded =
        raw == null ? [] : (jsonDecode(raw) as List<dynamic>);
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
        final subtotal = double.tryParse((item['subtotal'] ?? '0').toString()) ??
            ((double.tryParse((item['price'] ?? '0').toString()) ?? 0) *
                (int.tryParse((item['quantity'] ?? '0').toString()) ?? 0));
        total += subtotal;
      }

      return {
        "status": true,
        "data": items,
        "total": total.toStringAsFixed(2),
      };
    } catch (_) {
      return {"status": true, "data": [], "total": 0};
    }
  }

  static Future<void> clearLocalCart(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localCartKey(userId));
  }
}
