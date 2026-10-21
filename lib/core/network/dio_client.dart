import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../config/api_config.dart';
import '../storage/session_store.dart';

/// Paths that never carry an Authorization header (login/register, preflight).
const _unauthenticatedPaths = {'/auth/login', '/auth/register'};

class DioClient {
  final Dio dio;

  DioClient({Dio? dio})
      : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: ApiConfig.timeout,
                receiveTimeout: ApiConfig.timeout,
                sendTimeout: ApiConfig.timeout,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.method != 'OPTIONS' &&
              !_unauthenticatedPaths.contains(options.path)) {
            final token = sessionStore.cachedToken ?? await sessionStore.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
      ),
    );

    // Debug-only: response bodies hold order totals and profile data.
    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
        ),
      );
    }
  }

  Dio get _dio => dio;
}

final dioClient = DioClient();
