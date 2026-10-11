class ApiConfig {
  // Update via --dart-define=API_BASE_URL=https://<cosmetic-backend>.onrender.com/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cosmetic-app-zlmk.onrender.com/api',
  );
  static const Duration timeout = Duration(seconds: 30);
}
