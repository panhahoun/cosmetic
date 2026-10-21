import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';

/// Offline mirror of the server wishlist plus a global count notifier.
///
/// Mirrors [CartCache]: the server is authoritative, but the local list keeps
/// hearts and the wishlist tab working while offline or before the remote
/// response lands.
class WishlistCache {
  static String _key(int userId) => 'local_wishlist_$userId';

  static final ValueNotifier<int> wishlistCountNotifier = ValueNotifier<int>(0);

  static Future<List<Product>> getLocal(int userId) async {
    if (userId <= 0) return const <Product>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return const <Product>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Product>[];
      return decoded
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // Corrupt cache is treated as empty.
      return const <Product>[];
    }
  }

  static Future<void> save(int userId, List<Product> items) async {
    if (userId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = items
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'description': p.description,
              'price': p.price,
              'image': p.image,
              'category_name': p.categoryName,
              'brand': p.brand,
              'rating': p.rating,
              'review_count': p.reviewCount,
              'stock': p.stock,
              'size': p.size,
            },
          )
          .toList();
      await prefs.setString(_key(userId), jsonEncode(payload));
      wishlistCountNotifier.value = items.length;
    } catch (_) {
      // Non-fatal: the in-memory state still drives the UI this session.
    }
  }

  static Future<void> clear(int userId) async {
    if (userId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
      wishlistCountNotifier.value = 0;
    } catch (_) {
      // Non-fatal.
    }
  }
}