import 'package:get/get.dart';

import '../../features/auth/auth_binding.dart';
import '../../features/auth/login_view.dart';
import '../../features/auth/register_view.dart';
import '../../features/cart/cart_binding.dart';
import '../../features/cart/cart_view.dart';
import '../../features/home/home_binding.dart';
import '../../features/home/home_view.dart';
import '../../features/main/main_binding.dart';
import '../../features/main/main_view.dart';
import '../../features/profile/profile_binding.dart';
import '../../features/profile/profile_view.dart';
import '../../features/splash/splash_binding.dart';
import '../../features/splash/splash_view.dart';
import '../../features/wishlist/wishlist_view.dart';
import 'app_routes.dart';

class AppPages {
  static const String initial = AppRoutes.initial;

  static final List<GetPage> pages = [
    GetPage(
      name: AppRoutes.initial,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.main,
      page: () => const MainView(),
      binding: MainBinding(),
      bindings: [
        HomeBinding(),
        CartBinding(),
        ProfileBinding(),
      ],
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => HomeView(onOpenCart: () => Get.toNamed(AppRoutes.cart)),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.cart,
      page: () => const CartView(),
      binding: CartBinding(),
    ),
    GetPage(
      name: AppRoutes.wishlist,
      page: () => const WishlistView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => ProfileView(),
      binding: ProfileBinding(),
    ),
  ];
}
