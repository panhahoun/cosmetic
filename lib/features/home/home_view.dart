import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_colors.dart';
import '../../config/app_settings.dart';
import '../../data/cart_cache.dart';
import '../../widgets/product_card.dart';

import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  final VoidCallback onOpenCart;

  const HomeView({super.key, required this.onOpenCart});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final settings = AppSettings.instance;
    String tr(String key) => settings.t(key);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.scaffoldGradient(brightness),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('shop'),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            tr('find_daily'),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => settings.toggleTheme(),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                    IconButton(
                      onPressed: onOpenCart,
                      icon: const Icon(Icons.shopping_bag_outlined),
                    ),
                    PopupMenuButton<AppLanguage>(
                      icon: const Icon(Icons.language),
                      onSelected: (value) => settings.setLanguage(value),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: AppLanguage.english,
                          child: Text(tr('english')),
                        ),
                        PopupMenuItem(
                          value: AppLanguage.khmer,
                          child: Text(tr('khmer')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  onChanged: controller.setSearch,
                  decoration: InputDecoration(
                    hintText: tr('search_hint'),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Obx(
                () => SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = controller.categories[index];
                      final isSelected =
                          controller.selectedCategory.value == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => controller.setCategory(cat),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : AppColors.textPrimary),
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: AppColors.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FeaturedProductCard(
                  title: tr('featured_card_title'),
                  subtitle: tr('featured_card_subtitle'),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(
                  () {
                    if (controller.isLoading.value) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      );
                    }
                    final list = controller.filteredProducts;
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          tr('no_products'),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: controller.loadProducts,
                      color: AppColors.primary,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final product = list[index];
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
