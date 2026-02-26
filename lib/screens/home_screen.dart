import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String role = "";

  @override
  void initState() {
    super.initState();
    loadRole();
  }

  void loadRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString("role") ?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Cosmetic Shop"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
          )
        ],
      ),
      body: Center(
        child: role == "admin"
            ? Text("Welcome Admin Dashboard")
            : role == "cashier"
                ? Text("Welcome Cashier POS")
                : Text("Welcome User App"),
      ),
    );
  }
}