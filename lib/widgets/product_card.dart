import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_colors.dart';
import '../config/app_settings.dart';
import '../core/routes/app_routes.dart';
import '../core/storage/session_store.dart';
import '../models/product_model.dart';
import '../data/cart_cache.dart';
import '../data/cart_service_dio.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onAdded;

  const ProductCard({super.key, required this.product, this.onAdded});

  Future<void> _addToCart(BuildContext context) async {
    final settings = AppSettings.instance;
    String tr(String key) => settings.t(key);

    final userId = await sessionStore.currentUserId() ?? 0;
    if (userId <= 0) {
      Get.snackbar(
        tr('cart'),
        tr('please_login_add_to_cart'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      // Cart identity comes from the bearer token now; no user_id is sent.
      await CartServiceDio().addToCart(product.id, 1);
    } on CartException catch (e) {
      Get.snackbar(
        e.isUnauthorized ? tr('please_login_again') : tr('cart_update_failed'),
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await CartCache.addItem(
      userId: userId,
      productId: product.id,
      name: product.name,
      image: product.image,
      price: product.price,
      quantity: 1,
    );

    CartCache.markCartUpdated();
    await CartCache.refreshCartCountForCurrentUser();
    onAdded?.call();
    Get.snackbar(
      tr('cart'),
      tr('added_to_cart'),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Get.toNamed(AppRoutes.productDetail, arguments: product),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Hero(
                  tag: 'product-${product.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: double.infinity,
                      child: Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: isDark
                              ? AppColors.darkSurfaceAlt
                              : AppColors.secondary,
                          child: const Icon(
                            Icons.image_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _addToCart(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturedProductCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const FeaturedProductCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF2A252E), Color(0xFF211D24)]
              : const [Color(0xFFF4E4E7), Color(0xFFFCF9F7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
