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
      // Tabs stay alive in the IndexedStack, so refresh on every visit.
      if (Get.isRegistered<CartController>()) {
        Get.find<CartController>().reload();
      }
    }
    if (index == 1 && Get.isRegistered<WishlistController>()) {
      // Same for favorites: a heart toggled elsewhere must show up here.
      Get.find<WishlistController>().reload();
    }
    currentIndex.value = index;
  }
}
