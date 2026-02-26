import 'package:cosmetic/screens/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';
import '../config/app_settings.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Product>> _productsFuture;
  final TextEditingController _searchController = TextEditingController();
  int _cartCount = 0;
  String _selectedCategory = '';

  AppSettings get _settings => AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _productsFuture = ProductService.getProducts();
    _selectedCategory = tr('all');
    _refreshCartCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String tr(String key) => _settings.t(key);

  void _reloadProducts() {
    setState(() {
      _productsFuture = ProductService.getProducts();
    });
  }

  Future<void> _refreshCartCount() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('id') ?? 0;

    if (userId <= 0) {
      if (!mounted) return;
      setState(() => _cartCount = 0);
      return;
    }

    final remote = await CartService.getCart(userId);
    List<dynamic> items =
        remote['data'] is List ? (remote['data'] as List<dynamic>) : [];

    if (items.isEmpty) {
      final local = await CartService.getLocalCart(userId);
      items = local['data'] is List ? (local['data'] as List<dynamic>) : [];
    }

    int totalCount = 0;
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        totalCount += int.tryParse((item['quantity'] ?? 0).toString()) ?? 0;
      }
    }

    if (!mounted) return;
    setState(() => _cartCount = totalCount);
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _addToCart(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('id') ?? 0;

    if (userId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please login again')));
      return;
    }

    await CartService.addToCart(userId, product.id, 1);
    await CartService.addLocalCartItem(
      userId: userId,
      productId: product.id,
      name: product.name,
      image: product.image,
      price: product.price,
      quantity: 1,
    );

    await _refreshCartCount();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('added_to_cart'))));
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      ).then((_) => _refreshCartCount());
    }
  }

  List<String> _buildCategories(List<Product> products) {
    final categories = <String>{tr('all')};
    for (final p in products) {
      categories.add(p.categoryName);
    }
    return categories.toList();
  }

  List<Product> _filteredProducts(List<Product> products) {
    final query = _searchController.text.trim().toLowerCase();

    return products.where((product) {
      final byCategory = _selectedCategory == tr('all') ||
          product.categoryName.toLowerCase() == _selectedCategory.toLowerCase();
      if (!byCategory) return false;

      if (query.isEmpty) return true;

      return product.name.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query) ||
          product.categoryName.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildCartBadgeIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.shopping_cart_outlined),
        if (_cartCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _cartCount > 99 ? '99+' : _cartCount.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = _settings.themeMode == ThemeMode.dark;
            final isKhmer = _settings.language == AppLanguage.khmer;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('settings'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('dark_mode')),
                    value: isDark,
                    onChanged: (_) async {
                      await _settings.toggleTheme();
                      if (!mounted) return;
                      setState(() {});
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('language'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(tr('english')),
                          selected: !isKhmer,
                          onSelected: (_) async {
                            await _settings.setLanguage(AppLanguage.english);
                            if (!mounted) return;
                            setState(() {});
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(tr('khmer')),
                          selected: isKhmer,
                          onSelected: (_) async {
                            await _settings.setLanguage(AppLanguage.khmer);
                            if (!mounted) return;
                            setState(() {});
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : AppColors.textPrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('shop')),
        actions: [
          IconButton(
            icon: _buildCartBadgeIcon(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ).then((_) => _refreshCartCount());
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openSettingsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
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
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _StateMessage(
              title: tr('failed_load'),
              actionLabel: tr('retry'),
              onPressed: _reloadProducts,
            );
          }

          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return _StateMessage(
              title: tr('no_products'),
              actionLabel: tr('retry'),
              onPressed: _reloadProducts,
            );
          }

          final categories = _buildCategories(products);
          final filtered = _filteredProducts(products);

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
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('find_daily'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: tr('search_hint'),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                    
                    ],
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final selected = category == _selectedCategory;
                      return ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemCount: categories.length,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? _StateMessage(title: tr('no_products'))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(
                                        product: product,
                                        onAddToCart: _addToCart,
                                        tr: tr,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(18),
                                        ),
                                        child: Image.network(
                                          product.image,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '\$${product.price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 36,
                                            child: ElevatedButton(
                                              onPressed: () => _addToCart(product),
                                              child: Text(tr('add_to_cart')),
                                            ),
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final Future<void> Function(Product product) onAddToCart;
  final String Function(String key) tr;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.onAddToCart,
    required this.tr,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColors = isDark
        ? const [Color(0xFF10131A), Color(0xFF151927)]
        : const [Color(0xFFFFF5F8), Color(0xFFF8F8FC)];

    return Scaffold(
      appBar: AppBar(title: Text(tr('product_detail'))),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bgColors,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                child: SizedBox(
                  height: 320,
                  width: double.infinity,
                  child: Image.network(
                    product.image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetaTile(
                            label: tr('brand'),
                            value: product.brand,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetaTile(
                            label: tr('rating'),
                            value: '${product.rating} / 5',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr('description'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description.isNotEmpty
                          ? product.description
                          : 'Premium skincare product for daily routine.',
                      style: const TextStyle(
                        height: 1.5,
                        color: AppColors.textMuted,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await onAddToCart(product);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        child: Text(
                          tr('add_to_cart'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetaTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _StateMessage({
    required this.title,
    this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 10),
            ElevatedButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
