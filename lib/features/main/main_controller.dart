import 'package:get/get.dart';

import '../../data/cart_cache.dart';

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
    }
    currentIndex.value = index;
  }
}
