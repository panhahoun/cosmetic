import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  static String get baseUrl => ApiConfig.endpoint("auth");

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/register.php"),
            headers: {"Content-Type": "application/json"},
          body: jsonEncode({
              "name": name,
              "email": email,
              "password": password,
              "phone": phone,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {
          "status": false,
          "message": "Server error (${response.statusCode})",
        };
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }

      return {"status": false, "message": "Invalid server response"};
    } catch (_) {
      return {"status": false, "message": "Network error"};
    }
  }

  static Future<User?> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/login.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return null;
      }

      if (data['status'] == true && data['data'] is Map<String, dynamic>) {
        final user = User.fromJson(data['data']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt("id", user.id);
        await prefs.setString("name", user.name);
        await prefs.setString("email", user.email);
        await prefs.setString("role", user.role);

        return user;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
