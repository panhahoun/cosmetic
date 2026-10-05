import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get host {
    if (_apiHost.isNotEmpty) return _apiHost;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2';
      case TargetPlatform.iOS:
        return '127.0.0.1';
      default:
        return '127.0.0.1';
    }
  }

  static const Duration timeout = Duration(seconds: 12);

  // Use FastAPI base under /api; keep cosmetic_api prefix for compatibility if needed
  static String get baseUrl => 'http://$host:8000/api';
  static String get baseUrlLegacy => 'http://$host/cosmetic_api';
  static String endpoint(String module) => '$baseUrl/$module';
}
