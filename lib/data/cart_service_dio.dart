import 'dart:math';

import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';

/// A cart/order call that failed for a reason the UI should explain.
class CartException implements Exception {
  const CartException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// True when the session is missing or expired and the user must log in again.
  bool get isUnauthorized => statusCode == 401;

  /// True when the server refused for a business rule, e.g. not enough stock.
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

class CartServiceDio {
  final Dio _dio = dioClient.dio;

  static String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          return first['msg'].toString();
        }
      }
    }
    return fallback;
  }

  Never _rethrow(DioException e, String fallback) =>
      throw CartException(
        _errorMessage(e, fallback),
        statusCode: e.response?.statusCode,
      );

  /// Cart identity comes from the bearer token; no user id is sent.
  Future<Map<String, dynamic>> getCart() async {
    try {
      final res = await _dio.get('/cart/get_cart');
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return const {'status': false, 'data': <dynamic>[], 'total': 0};
      }
      data['data'] = data['data'] is List ? data['data'] : <dynamic>[];
      data['total'] = data['total'] ?? 0;
      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw CartException('Session expired. Please log in again.',
            statusCode: 401);
      }
      return const {'status': false, 'data': <dynamic>[], 'total': 0};
    }
  }

  Future<Map<String, dynamic>> addToCart(int productId, int quantity) async {
    try {
      final res = await _dio.post('/cart/add_to_cart', data: {
        'product_id': productId,
        'quantity': quantity,
      });
      return res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{'status': false};
    } on DioException catch (e) {
      _rethrow(e, 'Could not add to cart');
    }
  }

  Future<Map<String, dynamic>> updateCart(int productId, int quantity) async {
    try {
      final res = await _dio.post('/cart/update_cart', data: {
        'product_id': productId,
        'quantity': quantity,
      });
      return res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{'status': false};
    } on DioException catch (e) {
      _rethrow(e, 'Could not update cart');
    }
  }

  Future<Map<String, dynamic>> removeFromCart(int productId) async {
    try {
      final res = await _dio.post('/cart/remove_from_cart', data: {
        'product_id': productId,
      });
      return res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{'status': false};
    } on DioException catch (e) {
      _rethrow(e, 'Could not remove item');
    }
  }

  static final _random = Random();

  /// Places an order.
  ///
  /// `Idempotency-Key` stops a retry after a timeout creating a second order.
  Future<Map<String, dynamic>> checkout({
    String paymentMethod = 'cash_on_delivery',
    String? shippingAddress,
  }) async {
    final key = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '-${_random.nextInt(1 << 32).toRadixString(36)}';
    try {
      final res = await _dio.post(
        '/orders/checkout',
        data: {
          'payment_method': paymentMethod,
          'shipping_address': ?shippingAddress,
        },
        options: Options(headers: {'Idempotency-Key': key}),
      );
      return res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{'status': false};
    } on DioException catch (e) {
      _rethrow(e, 'Checkout failed');
    }
  }
}
