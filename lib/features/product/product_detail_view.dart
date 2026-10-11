import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_colors.dart';
import '../../config/app_settings.dart';
import '../../core/storage/session_store.dart';
import '../../data/cart_cache.dart';
import '../../data/cart_service_dio.dart';
import '../../models/product_model.dart';
import '../wishlist/wishlist_controller.dart';

class ProductDetailView extends StatefulWidget {
  final Product? product;

  const ProductDetailView({super.key, this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  int _quantity = 1;
  bool _adding = false;

  Product get _product => widget.product ?? (Get.arguments as Product);

  AppSettings get _settings => AppSettings.instance;
  String tr(String key) => _settings.t(key);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Future<void> _addToCart() async {
    if (_adding) return;

    final userId = await sessionStore.currentUserId() ?? 0;
    if (userId <= 0) {
      Get.snackbar(
        tr('cart'),
        tr('please_login_add_to_cart'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _adding = true);
    try {
      await CartServiceDio().addToCart(_product.id, _quantity);
    } on CartException catch (e) {
      Get.snackbar(
        e.isUnauthorized ? tr('please_login_again') : tr('cart_update_failed'),
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
      setState(() => _adding = false);
      return;
    }

    await CartCache.addItem(
      userId: userId,
      productId: _product.id,
      name: _product.name,
      image: _product.image,
      price: _product.price,
      quantity: _quantity,
    );

    CartCache.markCartUpdated();
    await CartCache.refreshCartCountForCurrentUser();
    if (mounted) setState(() => _adding = false);
    Get.snackbar(
      tr('cart'),
      tr('added_to_cart'),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Widget _favoriteAction(Product product) {
    final wishlist = Get.isRegistered<WishlistController>()
        ? Get.find<WishlistController>()
        : null;
    if (wishlist == null) return const SizedBox.shrink();
    return Obx(() {
      final fav = wishlist.isFavorite(product.id);
      return IconButton(
        onPressed: () => wishlist.toggle(product),
        tooltip: fav ? tr('removed_from_wishlist') : tr('added_to_wishlist'),
        icon: Icon(
          fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: fav ? AppColors.error : null,
        ),
      );
    });
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isDark ? AppColors.darkSurfaceAlt : AppColors.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final isDark = _isDark;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final outOfStock = product.stock <= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('product_detail')),
        actions: [_favoriteAction(product)],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Hero(
                      tag: 'product-${product.id}',
                      child: Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: isDark
                                ? AppColors.darkSurfaceAlt
                                : AppColors.secondary,
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: isDark
                              ? AppColors.darkSurfaceAlt
                              : AppColors.secondary,
                          child: const Icon(
                            Icons.image_outlined,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (product.brand.isNotEmpty)
                      _infoChip(Icons.spa_outlined, product.brand),
                    if (product.categoryName.isNotEmpty)
                      _infoChip(Icons.category_outlined, product.categoryName),
                    if (product.size.isNotEmpty)
                      _infoChip(Icons.square_foot_outlined, product.size),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    if (product.rating > 0) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${product.reviewCount})',
                        style: TextStyle(color: mutedColor, fontSize: 14),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('quantity'),
                        style: TextStyle(
                          color: mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          _QtyButton(
                            icon: Icons.remove_rounded,
                            onTap: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '$_quantity',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          ),
                          _QtyButton(
                            icon: Icons.add_rounded,
                            onTap: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: outOfStock
                        ? AppColors.error.withAlpha(15)
                        : AppColors.success.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        outOfStock
                            ? Icons.remove_shopping_cart_outlined
                            : Icons.check_circle_outline,
                        size: 18,
                        color: outOfStock ? AppColors.error : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        outOfStock
                            ? tr('out_of_stock')
                            : '${product.stock} ${tr('in_stock')}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: outOfStock
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  tr('description'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description.isNotEmpty
                      ? product.description
                      : tr('product_description_fallback'),
                  style: TextStyle(
                    color: mutedColor,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('price'),
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                      Text(
                        '\$${(product.price * _quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: outOfStock || _adding ? null : _addToCart,
                      child: _adding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : Text(tr('add_to_cart')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.secondary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
    );
  }
}
