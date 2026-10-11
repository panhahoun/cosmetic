import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_colors.dart';
import '../../config/app_settings.dart';
import '../../data/cart_cache.dart';
import '../../widgets/product_card.dart';
import 'wishlist_controller.dart';

class WishlistView extends GetView<WishlistController> {
  const WishlistView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    String tr(String key) => settings.t(key);

    return Scaffold(
      appBar: AppBar(title: Text(tr('wishlist'))),
      body: Obx(() {
        if (controller.isLoading.value && controller.items.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        if (controller.currentUserId.value <= 0) {
          return _EmptyHint(
            icon: Icons.lock_outline_rounded,
            text: tr('please_login_wishlist'),
          );
        }

        if (controller.items.isEmpty) {
          return _EmptyHint(
            icon: Icons.favorite_border_rounded,
            text: tr('wishlist_empty'),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.reload,
          color: AppColors.primary,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: controller.items.length,
            itemBuilder: (context, index) {
              final product = controller.items[index];
              return ProductCard(
                product: product,
                onAdded: () {
                  CartCache.markCartUpdated();
                  CartCache.refreshCartCountForCurrentUser();
                },
              );
            },
          ),
        );
      }),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: muted.withAlpha(180)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}