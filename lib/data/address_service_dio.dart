import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/address_model.dart';

/// An address call that failed for a reason the UI should explain.
class AddressException implements Exception {
  const AddressException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// True when the session is missing or expired and the user must log in again.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Address book data source. [AddressServiceDio] talks to the backend; tests
/// can substitute an in-memory implementation.
abstract class AddressService {
  Future<List<Address>> getAddresses();

  Future<Address> addAddress({
    required String fullName,
    required String phone,
    required String addressLine,
    String? city,
    String? postalCode,
    bool isDefault = false,
  });

  Future<Address> setDefault(int addressId);

  Future<void> deleteAddress(int addressId);
}

class AddressServiceDio implements AddressService {
  final Dio _dio = dioClient.dio;

  static String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    return fallback;
  }

  Never _rethrow(DioException e, String fallback) => throw AddressException(
    _errorMessage(e, fallback),
    statusCode: e.response?.statusCode,
  );

  static Address? _asAddress(dynamic data) {
    if (data is Map) return Address.fromJson(Map<String, dynamic>.from(data));
    return null;
  }

  @override
  Future<List<Address>> getAddresses() async {
    try {
      final res = await _dio.get('/addresses/get_addresses');
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final raw = data['data'];
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map(Address.fromJson)
              .toList();
        }
      }
      return const <Address>[];
    } on DioException catch (e) {
      _rethrow(e, 'Could not load addresses');
    }
  }

  @override
  Future<Address> addAddress({
    required String fullName,
    required String phone,
    required String addressLine,
    String? city,
    String? postalCode,
    bool isDefault = false,
  }) async {
    try {
      final res = await _dio.post(
        '/addresses/add_address',
        data: {
          'full_name': fullName,
          'phone': phone,
          'address_line': addressLine,
          'city': city,
          'postal_code': postalCode,
          'is_default': isDefault,
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final parsed = _asAddress(data['data']);
        if (parsed != null) return parsed;
      }
      return Address(
        id: 0,
        fullName: fullName,
        phone: phone,
        addressLine: addressLine,
        city: city ?? '',
        postalCode: postalCode ?? '',
        isDefault: isDefault,
      );
    } on DioException catch (e) {
      _rethrow(e, 'Could not save address');
    }
  }

  @override
  Future<Address> setDefault(int addressId) async {
    try {
      final res = await _dio.put(
        '/addresses/update_address/$addressId',
        data: {'is_default': true},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return _asAddress(data['data']) ??
            (Address.fromJson(Map<String, dynamic>.from(data)));
      }
      throw const AddressException('Could not set default address');
    } on DioException catch (e) {
      _rethrow(e, 'Could not set default address');
    }
  }

  @override
  Future<void> deleteAddress(int addressId) async {
    try {
      await _dio.delete('/addresses/delete_address/$addressId');
    } on DioException catch (e) {
      _rethrow(e, 'Could not delete address');
    }
  }
}
