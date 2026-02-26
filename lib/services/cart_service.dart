import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class CartService {
  static String get baseUrl => ApiConfig.endpoint("cart");

  static Future<Map<String, dynamic>> getCart(int userId) async {
    try {
      final response = await http.get(
          Uri.parse("$baseUrl/get_cart.php?user_id=$userId")).timeout(ApiConfig.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {
          "status": false,
          "message": "Server error (${response.statusCode})",
          "data": [],
          "total": 0,
        };
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        data['data'] = data['data'] is List ? data['data'] : [];
        data['total'] = data['total'] ?? 0;
        return data;
      }

      return {
        "status": false,
        "message": "Invalid server response",
        "data": [],
        "total": 0,
      };
    } catch (_) {
      return {
        "status": false,
        "message": "Network error",
        "data": [],
        "total": 0,
      };
    }
  }

  static Future<Map<String, dynamic>> checkout(int userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/checkout.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "payment_method": "cash"}),
      ).timeout(ApiConfig.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {
          "status": false,
          "message": "Server error (${response.statusCode})"
        };
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }

      return {"status": false, "message": "Invalid server response"};
    } catch (_) {
      return {"status": false, "message": "Network error"};
    }
  }

  static Future<Map<String, dynamic>> addToCart(
      int userId, int productId, int quantity) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_to_cart.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "product_id": productId,
          "quantity": quantity,
        }),
      ).timeout(ApiConfig.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {
          "status": false,
          "message": "Server error (${response.statusCode})"
        };
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }

      return {"status": false, "message": "Invalid server response"};
    } catch (_) {
      return {"status": false, "message": "Network error"};
    }
  }
}
