import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/order_model.dart';

/// An orders call that failed for a reason the UI should explain.
class OrdersException implements Exception {
  const OrdersException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// True when the session is missing or expired and the user must log in again.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Orders data source. [OrdersServiceDio] talks to the backend; tests can
/// substitute an in-memory implementation.
abstract class OrdersService {
  Future<List<Order>> getOrders({int limit = 50, int offset = 0});
}

class OrdersServiceDio implements OrdersService {
  final Dio _dio = dioClient.dio;

  static String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    return fallback;
  }

  Never _rethrow(DioException e, String fallback) => throw OrdersException(
    _errorMessage(e, fallback),
    statusCode: e.response?.statusCode,
  );

  @override
  Future<List<Order>> getOrders({int limit = 50, int offset = 0}) async {
    try {
      final res = await _dio.get(
        '/orders/get_orders',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final raw = data['data'];
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map(Order.fromJson)
              .toList();
        }
      }
      return const <Order>[];
    } on DioException catch (e) {
      _rethrow(e, 'Could not load orders');
    }
  }
}
