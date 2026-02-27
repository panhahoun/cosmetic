import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';
import '../config/app_settings.dart';
import '../services/cart_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? cartData;
  int userId = 0;
  bool isLoading = true;
  bool _syncingFromNotifier = false;

  AppSettings get _settings => AppSettings.instance;
  String tr(String key) => _settings.t(key);

  @override
  void initState() {
    super.initState();
    CartService.markCartViewed();
    CartService.cartCountNotifier.addListener(_onCartCountChanged);
    loadCart();
  }

  @override
  void dispose() {
    CartService.cartCountNotifier.removeListener(_onCartCountChanged);
    super.dispose();
  }

  void _onCartCountChanged() {
    if (!mounted || _syncingFromNotifier) return;

    final items = cartData != null && cartData!['data'] is List
        ? (cartData!['data'] as List)
        : <dynamic>[];
    final visibleCount = _totalItems(items);
    final targetCount = CartService.cartCountNotifier.value;

    if (visibleCount == targetCount) return;

    _syncingFromNotifier = true;
    loadCart().whenComplete(() {
      _syncingFromNotifier = false;
    });
  }

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('id') ?? 0;

    if (userId <= 0) {
      await CartService.refreshCartCount(0);
      if (!mounted) return;
      setState(() {
        cartData = {'data': [], 'total': 0};
        isLoading = false;
      });
      return;
    }

    final resolved = await CartService.getResolvedCart(userId);

    if (!mounted) return;
    setState(() {
      cartData = resolved;
      isLoading = false;
    });

    await CartService.refreshCartCount(userId);
  }

  Future<void> checkout() async {
    if (userId <= 0 || cartData == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(userId: userId, cartData: cartData!),
      ),
    );

    if (result == true) {
      // Checkout successful
      await loadCart();
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    if (userId <= 0) return;

    final source = (cartData?['source'] ?? '').toString();
    final productId =
        int.tryParse((item['product_id'] ?? item['id'] ?? 0).toString()) ?? 0;

    if (source == 'local' && productId > 0) {
      await CartService.removeLocalCartItem(userId, productId);
      await loadCart();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('remove_server_not_supported')),
      ),
    );
  }

  Future<void> _changeQuantity(Map<String, dynamic> item, int delta) async {
    if (userId <= 0 || delta == 0) return;

    final source = (cartData?['source'] ?? '').toString();
    final productId =
        int.tryParse((item['product_id'] ?? item['id'] ?? 0).toString()) ?? 0;
    if (productId <= 0) return;

    if (source == 'local') {
      final currentQty = int.tryParse((item['quantity'] ?? 0).toString()) ?? 0;
      final nextQty = currentQty + delta;
      if (nextQty <= 0) {
        await CartService.removeLocalCartItem(userId, productId);
      } else {
        await CartService.updateLocalCartItemQuantity(userId, productId, nextQty);
      }
      await loadCart();
      return;
    }

    if (delta > 0) {
      final result = await CartService.addToCart(userId, productId, delta);
      if (result['status'] == true) {
        await loadCart();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((result['message'] ?? tr('cart_update_failed')).toString()),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('remove_server_not_supported')),
      ),
    );
  }

  int _totalItems(List<dynamic> items) {
    var count = 0;
    for (final item in items) {
      if (item is Map) {
        count += int.tryParse((item['quantity'] ?? 0).toString()) ?? 0;
      }
    }
    return count;
  }

  String _formatPrice(dynamic value) {
    final amount = double.tryParse(value.toString()) ?? 0;
    return amount.toStringAsFixed(2);
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primary, size: 16),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        padding: const EdgeInsets.all(4),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      ),
    );
  }

  Widget _deleteButton({required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        padding: const EdgeInsets.all(4),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      ),
    );
  }

  Widget _qtyValue(dynamic quantity) {
    return Container(
      width: 42,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${int.tryParse((quantity ?? 0).toString()) ?? 0}',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
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
                '\$${_formatPrice(total)}',
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
    final itemCount = _totalItems(items);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [Color(0xFF10131A), Color(0xFF151927)]
              : const [Color(0xFFFFF5F8), Color(0xFFF8F8FC)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            tr('my_cart'),
            style: const TextStyle(letterSpacing: 0.5),
          ),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.remove_shopping_cart_rounded,
                            size: 80,
                            color: AppColors.textMuted.withAlpha(80),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('cart_empty'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _checkoutPanel(enabled: false),
                ],
              )
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('total_items'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '$itemCount',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final rawItem = items[index];
                        final item = rawItem is Map
                            ? Map<String, dynamic>.from(rawItem)
                            : <String, dynamic>{};
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
                                    (item['image'] ?? '').toString(),
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
                                        (item['name'] ?? '').toString(),
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
                                            '\$${_formatPrice(item['subtotal'])}',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                            ),
                                          ),
                                          Flexible(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  children: [
                                                    _qtyButton(
                                                      icon: Icons.add,
                                                      onPressed: () =>
                                                          _changeQuantity(
                                                            item,
                                                            1,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    _qtyValue(item['quantity']),
                                                    const SizedBox(width: 4),
                                                    _qtyButton(
                                                      icon: Icons.remove,
                                                      onPressed: () =>
                                                          _changeQuantity(
                                                            item,
                                                            -1,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    _deleteButton(
                                                      onPressed: () =>
                                                          _removeItem(item),
                                                    ),
                                                  ],
                                                ),
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
