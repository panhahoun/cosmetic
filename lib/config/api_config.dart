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

  static String endpoint(String module) => 'http://$host/cosmetic_api/$module';
}
