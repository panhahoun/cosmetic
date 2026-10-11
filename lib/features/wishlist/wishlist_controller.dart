import 'package:get/get.dart';

import '../../config/app_settings.dart';
import '../../core/storage/session_store.dart';
import '../../data/wishlist_cache.dart';
import '../../data/wishlist_service_dio.dart';
import '../../models/product_model.dart';

class WishlistController extends GetxController {
  WishlistController({WishlistService? service})
      : _service = service ?? WishlistServiceDio();

  final WishlistService _service;

  final items = <Product>[].obs;

  /// Ids of the currently favorited products, for cheap `isFavorite` lookups.
  final ids = <int>{}.obs;

  final isLoading = false.obs;
  final currentUserId = 0.obs;

  AppSettings get settings => AppSettings.instance;
  String tr(String key) => settings.t(key);

  bool isFavorite(int productId) => ids.contains(productId);

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    final id = await sessionStore.currentUserId() ?? 0;
    currentUserId.value = id;
    if (id <= 0) {
      items.clear();
      ids.clear();
      return;
    }

    isLoading.value = true;
    try {
      final remote = await _service.getWishlist();
      items.assignAll(remote);
      ids.assignAll(items.map((p) => p.id).toSet());
      await WishlistCache.save(id, items);
    } on WishlistException catch (e) {
      if (e.isUnauthorized) {
        // Session is gone: show nothing rather than a stale cached favorite.
        items.clear();
        ids.clear();
      } else {
        items.assignAll(await WishlistCache.getLocal(id));
        ids.assignAll(items.map((p) => p.id).toSet());
      }
    } catch (_) {
      items.assignAll(await WishlistCache.getLocal(id));
      ids.assignAll(items.map((p) => p.id).toSet());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggle(Product product) async {
    final id = await sessionStore.currentUserId() ?? 0;
    if (id <= 0) {
      Get.snackbar(
        tr('wishlist'),
        tr('please_login_wishlist'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final wasFavorite = isFavorite(product.id);

    // Optimistic update so the heart flips immediately.
    if (wasFavorite) {
      ids.remove(product.id);
      items.removeWhere((p) => p.id == product.id);
    } else {
      ids.add(product.id);
      if (!items.any((p) => p.id == product.id)) items.add(product);
    }
    Get.snackbar(
      tr('wishlist'),
      wasFavorite ? tr('removed_from_wishlist') : tr('added_to_wishlist'),
      snackPosition: SnackPosition.BOTTOM,
    );

    try {
      if (wasFavorite) {
        await _service.removeFromWishlist(product.id);
      } else {
        await _service.addToWishlist(product.id);
      }
      await WishlistCache.save(id, items.toList());
    } on WishlistException catch (e) {
      // Revert the optimistic change so the UI and server agree again.
      if (wasFavorite) {
        ids.add(product.id);
        if (!items.any((p) => p.id == product.id)) items.add(product);
      } else {
        ids.remove(product.id);
        items.removeWhere((p) => p.id == product.id);
      }
      Get.snackbar(tr('wishlist'), e.message, snackPosition: SnackPosition.BOTTOM);
    }
  }
}