import 'package:get/get.dart';

import 'wishlist_controller.dart';

class WishlistBinding extends Bindings {
  @override
  void dependencies() {
    // Registered on the /main route, so home cards, the detail screen and the
    // wishlist tab all share one instance. /main is never popped, so the
    // instance lives for the whole session.
    Get.lazyPut<WishlistController>(() => WishlistController());
  }
}