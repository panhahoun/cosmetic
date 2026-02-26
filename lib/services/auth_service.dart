import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = "http://10.0.2.2/cosmetic_api/auth";

  static Future<Map<String, dynamic>> register(
      String name, String email, String password, String phone) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "phone": phone
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<User?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password
      }),
    );

    final data = jsonDecode(response.body);

    if (data['status'] == true) {
      User user = User.fromJson(data['data']);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt("id", user.id);
      await prefs.setString("name", user.name);
      await prefs.setString("email", user.email);
      await prefs.setString("role", user.role);

      return user;
    }

    return null;
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}