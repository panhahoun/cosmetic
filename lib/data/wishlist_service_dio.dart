import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/product_model.dart';

/// A wishlist call that failed for a reason the UI should explain.
class WishlistException implements Exception {
  const WishlistException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// True when the session is missing or expired and the user must log in again.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Wishlist data source. [WishlistServiceDio] talks to the backend; tests can
/// substitute an in-memory implementation.
abstract class WishlistService {
  Future<List<Product>> getWishlist();

  Future<void> addToWishlist(int productId);

  Future<void> removeFromWishlist(int productId);
}

class WishlistServiceDio implements WishlistService {
  final Dio _dio = dioClient.dio;

  static String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    return fallback;
  }

  Never _rethrow(DioException e, String fallback) =>
      throw WishlistException(
        _errorMessage(e, fallback),
        statusCode: e.response?.statusCode,
      );

  @override
  Future<List<Product>> getWishlist() async {
    try {
      final res = await _dio.get('/wishlist/get_wishlist');
      final data = res.data;
      if (data is Map<String, dynamic> && data['status'] == true) {
        final raw = data['data'];
        if (raw is List) return raw.map((e) => Product.fromJson(e)).toList();
      }
      return const <Product>[];
    } on DioException catch (e) {
      _rethrow(e, 'Could not load wishlist');
    }
  }

  @override
  Future<void> addToWishlist(int productId) async {
    try {
      await _dio.post('/wishlist/add', data: {'product_id': productId});
    } on DioException catch (e) {
      _rethrow(e, 'Could not add to wishlist');
    }
  }

  @override
  Future<void> removeFromWishlist(int productId) async {
    try {
      await _dio.post('/wishlist/remove', data: {'product_id': productId});
    } on DioException catch (e) {
      _rethrow(e, 'Could not remove from wishlist');
    }
  }
}