import 'package:get/get.dart';

import '../../config/app_settings.dart';
import '../../core/storage/session_store.dart';
import '../../data/cart_cache.dart';
import '../../data/cart_service_dio.dart';

class CartController extends GetxController {
  final CartServiceDio _cartServiceDio = CartServiceDio();

  final cartItems = <Map<String, dynamic>>[].obs;
  final total = 0.0.obs;
  final isLoading = false.obs;
  final userId = 0.obs;

  /// Set when the last call failed because the session is gone, so the view can
  /// prompt for a re-login instead of showing a generic error.
  final sessionExpired = false.obs;

  AppSettings get settings => AppSettings.instance;
  String tr(String key) => settings.t(key);

  static bool _firstInit = true;

  @override
  void onInit() {
    super.onInit();
    // CartCache needs to read the server cart for the badge count without
    // depending on Dio itself.
    CartCacheRemoteBridge.itemsLoader = (id) => CartServiceDio().getCart();
    if (_firstInit) {
      _firstInit = false;
      loadUserId();
    }
  }

  Future<void> loadUserId() async {
    userId.value = await sessionStore.currentUserId() ?? 0;
    await loadCart();
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> loadCart() async {
    isLoading.value = true;
    try {
      final resolved = await CartCache.resolve(userId.value);
      final raw = resolved['data'];
      cartItems.assignAll(
        raw is List ? raw.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[],
      );
      total.value = _asDouble(resolved['total']);
    } finally {
      isLoading.value = false;
    }
  }

  /// Wraps a server call so business-rule failures (409) and expired sessions
  /// (401) reach the user as a specific message.
  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      sessionExpired.value = false;
      return true;
    } on CartException catch (e) {
      if (e.isUnauthorized) {
        sessionExpired.value = true;
        Get.snackbar(tr('cart'), tr('please_login_again'),
            snackPosition: SnackPosition.BOTTOM);
      } else if (e.isConflict) {
        Get.snackbar(tr('cart'), e.message,
            snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar(tr('cart_update_failed'), e.message,
            snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
  }

  Future<void> updateQuantity(int productId, int quantity) async {
    final ok = await _guard(() async {
      if (userId.value <= 0) {
        await CartCache.updateQuantity(userId.value, productId, quantity);
      } else {
        await _cartServiceDio.updateCart(productId, quantity);
      }
    });
    if (!ok) return;
    await loadCart();
    unawaitedRefreshCount();
  }

  Future<void> removeItem(int productId) async {
    final ok = await _guard(() async {
      if (userId.value <= 0) {
        await CartCache.removeItem(userId.value, productId);
      } else {
        await _cartServiceDio.removeFromCart(productId);
      }
    });
    if (!ok) return;
    await loadCart();
    unawaitedRefreshCount();
  }

  Future<void> addItem({
    required int productId,
    required String name,
    required String image,
    required double price,
    int quantity = 1,
  }) async {
    final ok = await _guard(() async {
      if (userId.value <= 0) {
        Get.snackbar(tr('cart'), tr('please_login_add_to_cart'),
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      await _cartServiceDio.addToCart(productId, quantity);
      await CartCache.addItem(
        userId: userId.value,
        productId: productId,
        name: name,
        image: image,
        price: price,
        quantity: quantity,
      );
      CartCache.markCartUpdated();
    });
    if (!ok) return;
    await loadCart();
    unawaitedRefreshCount();
    if (sessionExpired.value == false && userId.value > 0) {
      Get.snackbar(tr('cart'), tr('added_to_cart'),
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> checkout({String? shippingAddress}) async {
    isLoading.value = true;
    try {
      if (userId.value <= 0) {
        await CartCache.clearLocalCart(userId.value);
        cartItems.clear();
        total.value = 0;
        Get.snackbar(tr('checkout'), tr('order_placed_local'),
            snackPosition: SnackPosition.BOTTOM);
      } else {
        final res = await _cartServiceDio.checkout(
          shippingAddress: shippingAddress,
        );
        if (res['status'] == true) {
          // Clear the offline mirror unconditionally. It used to survive
          // checkout, and getResolvedCart prefers whichever side has more
          // items, so a stale cache could resurrect an emptied cart.
          await CartCache.clearLocalCart(userId.value);
          cartItems.clear();
          total.value = 0;
          Get.snackbar(
            tr('checkout'),
            res['message']?.toString() ?? tr('order_success'),
            snackPosition: SnackPosition.BOTTOM,
          );
        } else {
          Get.snackbar(
            tr('checkout_failed'),
            res['message']?.toString() ?? tr('checkout_failed_try_again'),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } on CartException catch (e) {
      Get.snackbar(
        e.isUnauthorized ? tr('please_login_again') : tr('checkout_failed'),
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
      unawaitedRefreshCount();
    }
  }

  void unawaitedRefreshCount() {
    CartCache.refreshCartCountForCurrentUser();
  }
}
