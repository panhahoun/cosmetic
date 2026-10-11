import 'package:get/get.dart';

import '../../data/cart_cache.dart';
import '../cart/cart_controller.dart';
import '../wishlist/wishlist_controller.dart';

class MainController extends GetxController {
  final currentIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    CartCache.refreshCartCountForCurrentUser();
  }

  void changeIndex(int index) {
    if (index == 2) {
      CartCache.markCartViewed();
      // The cart tab stays alive inside MainView's IndexedStack, so its list
      // is stale until it is reloaded here on every visit. Reloading also
      // picks up a login that happened after startup.
      if (Get.isRegistered<CartController>()) {
        Get.find<CartController>().reload();
      }
    }
    if (index == 1 && Get.isRegistered<WishlistController>()) {
      // Same staleness fix for favorites: refresh on every visit so a heart
      // toggled from home/detail (or a fresh login) is reflected here.
      Get.find<WishlistController>().reload();
    }
    currentIndex.value = index;
  }
}
