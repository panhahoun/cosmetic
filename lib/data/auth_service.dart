import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../core/storage/session_store.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthService {
  final Dio _dio = dioClient.dio;

  /// Extracts a human-readable message from a FastAPI error body.
  ///
  /// FastAPI returns `{"detail": "..."}` for HTTPException and
  /// `{"detail": [{loc, msg, type}]}` for request-validation failures.
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

  Future<void> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    try {
      await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      });
    } on DioException catch (e) {
      throw AuthException(
        _errorMessage(e, 'Registration failed'),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<User> login(String email, String password) async {
    late final Map<String, dynamic> body;
    try {
      final res = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw const AuthException('Invalid response from server');
      }
      body = data;
    } on DioException catch (e) {
      // 401 means the credentials were rejected.
      throw AuthException(
        _errorMessage(e, 'Login failed'),
        statusCode: e.response?.statusCode,
      );
    }

    final token = body['access_token'];
    final userData = body['data'];
    if (token is! String || token.isEmpty || userData is! Map<String, dynamic>) {
      throw const AuthException('Login response missing token');
    }

    final user = User.fromJson(userData);
    // Persist the token or every authenticated request goes out anonymous.
    await sessionStore.saveSession(
      token: token,
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
    );
    return user;
  }

  Future<void> logout() => sessionStore.clear();
}
