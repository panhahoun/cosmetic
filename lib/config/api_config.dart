class ApiConfig {
  // Update via --dart-define=API_BASE_URL=https://<cosmetic-backend>.onrender.com/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );
  static const Duration timeout = Duration(seconds: 30);
}
