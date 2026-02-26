import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cart_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? cartData;
  int userId = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCart();
  }

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt("id") ?? 0;

    if (userId <= 0) {
      if (!mounted) return;
      setState(() {
        cartData = {"data": [], "total": 0};
        isLoading = false;
      });
      return;
    }

    final data = await CartService.getCart(userId);

    if (!mounted) return;
    setState(() {
      cartData = data;
      isLoading = false;
    });
  }

  Future<void> checkout() async {
    if (userId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login again")));
      return;
    }

    final result = await CartService.checkout(userId);

    if (!mounted) return;

    if (result['status'] == true) {
      await loadCart();
      if (!mounted) return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          result['status'] == true
              ? (result['message'] ?? "Checkout successful")
              : (result['message'] ?? "Checkout failed"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Cart")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : cartData == null || (cartData!['data'] as List).isEmpty
          ? Center(child: Text("Cart is empty"))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartData!['data'].length,
                    itemBuilder: (context, index) {
                      final item = cartData!['data'][index];

                      return Card(
                        margin: EdgeInsets.all(8),
                        child: ListTile(
                          leading: Image.network(
                            item['image'],
                            width: 50,
                            fit: BoxFit.cover,
                          ),
                          title: Text(item['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Price: \$${item['price']}"),
                              Text("Qty: ${item['quantity']}"),
                              Text("Subtotal: \$${item['subtotal']}"),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                /// TOTAL + CHECKOUT
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "\$${cartData!['total']}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.pink,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          minimumSize: Size(double.infinity, 45),
                        ),
                        onPressed: checkout,
                        child: Text("Checkout"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
