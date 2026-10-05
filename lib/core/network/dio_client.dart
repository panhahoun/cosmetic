import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../config/api_config.dart';
import '../storage/session_store.dart';

/// Paths that must never carry an Authorization header. Attaching a token to
/// login/register is harmless but noisy; attaching it to a preflight OPTIONS
/// can trip strict origins.
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

    // Response bodies contain order totals and profile data; the logger is a
    // debug-only affordance so release builds do not write them to logcat.
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
