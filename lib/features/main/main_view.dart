import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_colors.dart';
import '../../config/app_settings.dart';
import '../../data/cart_cache.dart';
import '../cart/cart_view.dart';
import '../home/home_view.dart';
import '../profile/profile_view.dart';
import '../wishlist/wishlist_view.dart';
import 'main_controller.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  Widget _cartNavIcon({required bool selected}) {
    final baseIcon = Icon(
      selected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
      color: selected ? AppColors.primary : null,
    );
    return ValueListenableBuilder<bool>(
      valueListenable: CartCache.cartUnreadNotifier,
      builder: (context, hasUnread, child) {
        if (!hasUnread) return baseIcon;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            baseIcon,
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.3,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    String tr(String key) => settings.t(key);

    return Obx(
      () => Scaffold(
        body: IndexedStack(
          index: controller.currentIndex.value,
          children: [
            HomeView(onOpenCart: () => controller.changeIndex(2)),
            const WishlistView(),
            const CartView(),
            ProfileView(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.currentIndex.value,
          onDestinationSelected: controller.changeIndex,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: tr('home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.favorite_border_rounded),
              selectedIcon: const Icon(Icons.favorite_rounded),
              label: tr('wishlist'),
            ),
            NavigationDestination(
              icon: _cartNavIcon(selected: controller.currentIndex.value == 2),
              selectedIcon:
                  _cartNavIcon(selected: controller.currentIndex.value == 2),
              label: tr('cart'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: tr('profile'),
            ),
          ],
        ),
      ),
    );
  }
}
