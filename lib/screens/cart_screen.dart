import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';
import '../config/app_settings.dart';
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

  AppSettings get _settings => AppSettings.instance;
  String tr(String key) => _settings.t(key);

  @override
  void initState() {
    super.initState();
    loadCart();
  }

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('id') ?? 0;

    if (userId <= 0) {
      if (!mounted) return;
      setState(() {
        cartData = {'data': [], 'total': 0};
        isLoading = false;
      });
      return;
    }

    final data = await CartService.getCart(userId);
    final remoteItems = data['data'] is List ? (data['data'] as List) : [];

    Map<String, dynamic> resolved = Map<String, dynamic>.from(data);
    resolved['source'] = 'server';

    if (remoteItems.isEmpty) {
      final localData = await CartService.getLocalCart(userId);
      final localItems = localData['data'] is List
          ? (localData['data'] as List)
          : [];
      if (localItems.isNotEmpty) {
        resolved = Map<String, dynamic>.from(localData);
        resolved['source'] = 'local';
      }
    }

    if (!mounted) return;
    setState(() {
      cartData = resolved;
      isLoading = false;
    });
  }

  Future<void> checkout() async {
    if (userId <= 0) return;

    final isLocalOnly = cartData?['source'] == 'local';
    if (isLocalOnly) {
      await CartService.clearLocalCart(userId);
      await loadCart();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('purchase'))));
      return;
    }

    final result = await CartService.checkout(userId);

    if (!mounted) return;

    if (result['status'] == true) {
      await CartService.clearLocalCart(userId);
      await loadCart();
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['status'] == true
              ? (result['message'] ?? tr('checkout'))
              : (result['message'] ?? 'Checkout failed'),
        ),
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) Navigator.pop(context);
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    // Basic implementation for removing an item locally.
    // If backend syncing is needed, CartService needs a remove method.
    final cartList = cartData?['data'] as List?;
    if (cartList != null) {
      setState(() {
        cartList.remove(item);
        // Recalculate total
        double newTotal = 0;
        for (var i in cartList) {
          newTotal += (i['subtotal'] ?? 0);
        }
        cartData?['total'] = newTotal;
      });
      // Optionally trigger local save if supported
    }
  }

  Widget _checkoutPanel({required bool enabled}) {
    final total = cartData?['total'] ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('total'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '\$$total',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: AppColors.primary.withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: enabled ? checkout : null,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                tr('checkout'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = cartData != null && cartData!['data'] is List
        ? (cartData!['data'] as List)
        : <dynamic>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('my_cart'), style: const TextStyle(letterSpacing: 0.5)),
        centerTitle: false,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: 1,
          elevation: 0,
          onDestinationSelected: _onBottomNavTapped,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(
                Icons.home_rounded,
                color: AppColors.primary,
              ),
              label: tr('home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.shopping_bag_outlined),
              selectedIcon: const Icon(
                Icons.shopping_bag_rounded,
                color: AppColors.primary,
              ),
              label: tr('cart'),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF10131A), Color(0xFF151927)]
                : const [Color(0xFFFFF5F8), Color(0xFFF8F8FC)],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
            ? Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        tr('cart_empty'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  _checkoutPanel(enabled: false),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      item['image'],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '\$${item['subtotal']}',
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withAlpha(20),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${tr('quantity')}: ${item['quantity']}',
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                      },
                    ),
                  ),
                  _checkoutPanel(enabled: true),
                ],
              ),
      ),
    );
  }
}

