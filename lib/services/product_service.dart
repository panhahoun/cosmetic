import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';

class ProductService {
  static const String baseUrl =
      "http://10.0.2.2/cosmetic_api/products";

  static Future<List<Product>> getProducts() async {
    final response =
        await http.get(Uri.parse("$baseUrl/get_products.php"));

    final data = jsonDecode(response.body);

    if (data['status'] == true) {
      return (data['data'] as List)
          .map((e) => Product.fromJson(e))
          .toList();
    }

    return [];
  }
}