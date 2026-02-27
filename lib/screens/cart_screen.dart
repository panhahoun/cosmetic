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
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _openCartItemDetail(item),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(tr('cart_detail')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF10131A), Color(0xFF151927)]
                : const [Color(0xFFFFF5F8), Color(0xFFF8F8FC)],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 380,
                    width: double.infinity,
                    child: Image.network(
                      item['image']?.toString() ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha(80),
                            Colors.transparent,
                            isDark
                                ? const Color(0xFF10131A)
                                : const Color(0xFFFFF5F8),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Transform.translate(
                offset: const Offset(0, -30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']?.toString() ?? 'Product',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('order_summary'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _detailRow(tr('price'), '\$${item['price'] ?? 0}'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                            _detailRow(
                              tr('quantity'),
                              '${item['quantity'] ?? 0}',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tr('subtotal'),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '\$${item['subtotal'] ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _detailRow(
                                    tr('delivery'),
                                    'Standard (2-4 days)',
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.payment_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _detailRow(
                                    tr('payment'),
                                    'Cash on delivery',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 4,
                            shadowColor: AppColors.primary.withAlpha(100),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: Text(
                            tr('purchase'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
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
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
