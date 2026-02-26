import 'dart:convert';
import 'package:http/http.dart' as http;

class CartService {
  static const String baseUrl =
      "http://10.0.2.2/cosmetic_api/cart";

  static Future<Map<String, dynamic>> getCart(int userId) async {
    final response = await http.get(
        Uri.parse("$baseUrl/get_cart.php?user_id=$userId"));

    return jsonDecode(response.body);
  }

  static Future<void> checkout(int userId) async {
    await http.post(
      Uri.parse("$baseUrl/checkout.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "payment_method": "cash"
      }),
    );
  }

  static Future<void> addToCart(
    int userId, int productId, int quantity) async {

  await http.post(
    Uri.parse("$baseUrl/add_to_cart.php"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "user_id": userId,
      "product_id": productId,
      "quantity": quantity
    }),
  );
}
}