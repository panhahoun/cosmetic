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
      final localItems =
          localData['data'] is List ? (localData['data'] as List) : [];
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('purchase'))));
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

  Future<void> _openCartItemDetail(Map<String, dynamic> item) async {
    final shouldCheckout = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CartItemDetailScreen(item: item)),
    );

    if (shouldCheckout == true) {
      await checkout();
    }
  }

  Widget _checkoutPanel({required bool enabled}) {
    final total = cartData?['total'] ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('total'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                '\$$total',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: enabled ? checkout : null,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(tr('checkout')),
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
      appBar: AppBar(title: Text(tr('my_cart'))),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: _onBottomNavTapped,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: tr('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_cart_outlined),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: tr('cart'),
          ),
        ],
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
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(10),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    item['image'],
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                title: Text(
                                  item['name'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${tr('quantity')}: ${item['quantity']}  •  \$${item['subtotal']}',
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => _openCartItemDetail(item),
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

class CartItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;

  const CartItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final tr = settings.t;

    return Scaffold(
      appBar: AppBar(title: Text(tr('cart_detail'))),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  item['image']?.toString() ?? '',
                  width: double.infinity,
                  height: 240,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item['name']?.toString() ?? 'Product',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('order_summary'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _detailRow(tr('price'), '\$${item['price'] ?? 0}'),
                      _detailRow(tr('quantity'), '${item['quantity'] ?? 0}'),
                      _detailRow(tr('subtotal'), '\$${item['subtotal'] ?? 0}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _detailRow(tr('delivery'), 'Standard (2-4 days)'),
                      const SizedBox(height: 8),
                      _detailRow(tr('payment'), 'Cash on delivery'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(tr('purchase')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textMuted)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
