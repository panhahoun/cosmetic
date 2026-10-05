import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import '../core/network/dio_client.dart';
import '../models/product_model.dart';

class ProductService {
  final Dio _dio = dioClient.dio;

  Future<List<Product>> getProducts() async {
    try {
      final res = await _dio.get('/products/get_products');
      final data = res.data;
      if (data is Map<String, dynamic> && data['status'] == true) {
        final raw = data['data'];
        if (raw is List) {
          final parsed = raw.map((e) => Product.fromJson(e)).toList();
          if (parsed.isNotEmpty) return parsed;
        }
      }
      return _loadSeed();
    } on DioException catch (_) {
      return _loadSeed();
    }
  }

  Future<List<Product>> _loadSeed() async {
    try {
      final rawJson = await rootBundle.loadString('assets/data/products_seed.json');
      final data = jsonDecode(rawJson);
      if (data is List) {
        return data.map((e) => Product.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }
}
