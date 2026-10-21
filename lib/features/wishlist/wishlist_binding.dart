import 'package:get/get.dart';

import 'wishlist_controller.dart';

class WishlistBinding extends Bindings {
  @override
  void dependencies() {
    // One instance for the whole session: /main is never popped.
    Get.lazyPut<WishlistController>(() => WishlistController());
  }
}