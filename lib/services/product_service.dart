import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../models/product_model.dart';

class ProductService {
  static String get baseUrl => ApiConfig.endpoint("products");

  static Future<List<Product>> getProducts() async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/get_products.php"))
          .timeout(ApiConfig.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _loadSeedProducts();
      }

      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic> && data['status'] == true) {
        final rawList = data['data'];
        if (rawList is List) {
          final parsed = rawList.map((e) => Product.fromJson(e)).toList();
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      }

      return _loadSeedProducts();
    } catch (_) {
      return _loadSeedProducts();
    }
  }

  static Future<List<Product>> _loadSeedProducts() async {
    try {
      final rawJson = await rootBundle.loadString(
        'assets/data/products_seed.json',
      );
      final data = jsonDecode(rawJson);

      if (data is List) {
        final parsed = data.map((e) => Product.fromJson(e)).toList();
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }

      return _inMemorySeedProducts();
    } catch (_) {
      return _inMemorySeedProducts();
    }
  }

  static List<Product> _inMemorySeedProducts() {
    return [
      Product(
        id: 9001,
        name: 'Hydra Dew Gel Cleanser',
        description: 'Gentle daily cleanser for all skin types.',
        price: 18.0,
        image: 'https://picsum.photos/seed/cleanser1/600/600',
        categoryName: 'Cleanser',
        brand: 'Lumiere',
        rating: 4.7,
        reviewCount: 312,
        stock: 24,
        size: '150ml',
      ),
      Product(
        id: 9002,
        name: 'Peptide Bounce Serum',
        description: 'Lightweight serum for elasticity and glow.',
        price: 29.0,
        image: 'https://picsum.photos/seed/serum1/600/600',
        categoryName: 'Serum',
        brand: 'NovaSkin',
        rating: 4.8,
        reviewCount: 521,
        stock: 18,
        size: '30ml',
      ),
      Product(
        id: 9003,
        name: 'UV Shield SPF 50+',
        description: 'Invisible sunscreen with broad-spectrum protection.',
        price: 21.0,
        image: 'https://picsum.photos/seed/sun1/600/600',
        categoryName: 'Sunscreen',
        brand: 'RayDef',
        rating: 4.8,
        reviewCount: 640,
        stock: 37,
        size: '50ml',
      ),
      Product(
        id: 9004,
        name: 'Ceramide Cloud Cream',
        description: 'Moisturizer for dry and sensitive skin.',
        price: 26.0,
        image: 'https://picsum.photos/seed/moist1/600/600',
        categoryName: 'Moisturizer',
        brand: 'DermaNest',
        rating: 4.9,
        reviewCount: 390,
        stock: 13,
        size: '50ml',
      ),
    ];
  }
}
