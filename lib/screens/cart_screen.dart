import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cart_service.dart';

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt("id") ?? 0;

    final data = await CartService.getCart(userId);

    setState(() {
      cartData = data;
      isLoading = false;
    });
  }

  Future<void> checkout() async {
    await CartService.checkout(userId);
    await loadCart();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Checkout successful")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Cart")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : cartData == null || cartData!['data'].isEmpty
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
