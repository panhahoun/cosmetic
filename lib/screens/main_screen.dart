import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../config/app_settings.dart';
import '../services/cart_service.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pages = [
      HomeScreen(onOpenCart: () => _onBottomNavTapped(2)),
      const WishlistScreen(),
      const CartScreen(),
      const ProfileScreen(),
    ];
    CartService.refreshCartCountForCurrentUser();
    if (_currentIndex == 2) {
      CartService.markCartViewed();
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == 2) {
      CartService.markCartViewed();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _cartNavIcon({required bool selected}) {
    final baseIcon = Icon(
      selected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
      color: selected ? AppColors.primary : null,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: CartService.cartUnreadNotifier,
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
                  color: Colors.redAccent,
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

  // To build Cart Badge inside MainScreen, we should fetch count somehow, or simply show icon.
  // For now, we will rely on CartScreen updating the overall cart state or use a simple icon.

  @override
  Widget build(BuildContext context) {
    final tr = AppSettings.instance.t;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
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
          selectedIndex: _currentIndex,
          onDestinationSelected: _onBottomNavTapped,
          elevation: 0,
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
              icon: const Icon(Icons.favorite_outline),
              selectedIcon: const Icon(
                Icons.favorite_rounded,
                color: AppColors.primary,
              ),
              label: tr('wishlist'),
            ),
            NavigationDestination(
              icon: _cartNavIcon(selected: false),
              selectedIcon: _cartNavIcon(selected: true),
              label: tr('cart'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
              ),
              label: tr('profile'),
            ),
          ],
        ),
      ),
    );
  }
}
