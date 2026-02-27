import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';

class WishlistService {
  static const String _keyPrefix = 'wishlist_';

  /// Adds a product to the user's wishlist
  static Future<void> addToWishlist(int userId, Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$userId';

    final List<String> currentList = prefs.getStringList(key) ?? [];

    // Check if empty or not containing this product id already
    bool exists = false;
    for (String itemStr in currentList) {
      final Map<String, dynamic> item = jsonDecode(itemStr);
      if (item['id'] == product.id) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      final productMap = {
        'id': product.id,
        'name': product.name,
        'description': product.description,
        'price': product.price,
        'image': product.image,
        'category_name': product.categoryName,
        'brand': product.brand,
        'rating': product.rating,
        'review_count': product.reviewCount,
        'stock': product.stock,
        'size': product.size,
      };
      currentList.add(jsonEncode(productMap));
      await prefs.setStringList(key, currentList);
    }
  }

  /// Removes a product from the user's wishlist
  static Future<void> removeFromWishlist(int userId, int productId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$userId';

    final List<String> currentList = prefs.getStringList(key) ?? [];
    currentList.removeWhere((itemStr) {
      final Map<String, dynamic> item = jsonDecode(itemStr);
      return item['id'] == productId;
    });

    await prefs.setStringList(key, currentList);
  }

  /// Checks if a product exists in the user's wishlist
  static Future<bool> isFavorite(int userId, int productId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$userId';

    final List<String> currentList = prefs.getStringList(key) ?? [];
    for (String itemStr in currentList) {
      final Map<String, dynamic> item = jsonDecode(itemStr);
      if (item['id'] == productId) {
        return true;
      }
    }
    return false;
  }

  /// Gets all products in the user's wishlist
  static Future<List<Product>> getWishlist(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$userId';

    final List<String> currentList = prefs.getStringList(key) ?? [];
    return currentList.map((itemStr) {
      final Map<String, dynamic> item = jsonDecode(itemStr);
      return Product.fromJson(item);
    }).toList();
  }
}
