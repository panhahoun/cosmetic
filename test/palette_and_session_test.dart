import 'package:cosmetic/config/app_colors.dart';
import 'package:cosmetic/core/storage/session_store.dart';
import 'package:cosmetic/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppColors palette', () {
    test('core tokens match the documented M-Commerce palette', () {
      expect(AppColors.primary, const Color(0xFFC98F9B));
      expect(AppColors.secondary, const Color(0xFFF4E4E7));
      expect(AppColors.background, const Color(0xFFFCF9F7));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.textPrimary, const Color(0xFF2D2526));
      expect(AppColors.textMuted, const Color(0xFF7D7374));
      expect(AppColors.accent, const Color(0xFFC6A15B));
      expect(AppColors.border, const Color(0xFFE8DDDA));
      expect(AppColors.success, const Color(0xFF6F8A72));
      expect(AppColors.error, const Color(0xFFC65D63));
      expect(AppColors.navUnselected, const Color(0xFFA69B9C));
    });

    test('gradients have light and dark variants', () {
      expect(AppColors.scaffoldGradient(Brightness.light).length, 2);
      expect(AppColors.scaffoldGradient(Brightness.dark).length, 2);
      expect(AppColors.cardGradient(Brightness.light).length, 2);
      expect(AppColors.cardGradient(Brightness.dark).length, 2);
      expect(
        AppColors.scaffoldGradient(Brightness.dark),
        isNot(AppColors.scaffoldGradient(Brightness.light)),
      );
    });

    test('primaryAlpha produces a translucent rose', () {
      final tinted = AppColors.primaryAlpha(0.2);
      expect(tinted.a, closeTo(0.2, 0.001));
      expect(tinted.r, closeTo(AppColors.primary.r, 0.001));
    });
  });

  group('SessionStore', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('readToken is null and cachedToken is null before priming', () async {
      // No platform channels are mocked here, so the secure-storage read
      // throws and must be swallowed rather than propagate.
      expect(await sessionStore.readToken(), isNull);
      expect(sessionStore.cachedToken, isNull);
    });

    test('clear does not throw when the keystore is unavailable', () async {
      await expectLater(sessionStore.clear(), completes);
      expect(sessionStore.cachedToken, isNull);
    });

    test('currentUserId is null when nothing is stored', () async {
      expect(await sessionStore.currentUserId(), isNull);
    });

    test('currentUserId reads the stored id', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'id': 42});
      expect(await sessionStore.currentUserId(), 42);
    });
  });

  group('Product model', () {
    test('parses a backend product payload', () {
      final product = Product.fromJson({
        'id': 9001,
        'name': 'Hydra Dew Gel Cleanser',
        'price': 18.0,
        'image': 'https://example.com/a.png',
        'brand': 'Lumiere',
        'size': '150ml',
        'rating': 4.7,
        'review_count': 312,
        'category_name': 'Cleanser',
      });

      expect(product.id, 9001);
      expect(product.name, 'Hydra Dew Gel Cleanser');
      expect(product.price, 18.0);
      expect(product.brand, 'Lumiere');
    });

    test('a genuine rating of zero is not replaced with a default', () {
      // Guard: a real 0 rating must not become 4.5.
      final product = Product.fromJson({
        'id': 1,
        'name': 'Unrated',
        'price': 1.0,
        'rating': 0,
      });
      expect(product.rating, 0);
    });

    test('missing optional fields do not fabricate data', () {
      final product = Product.fromJson({'id': 2, 'name': 'Bare', 'price': 5});
      expect(product.brand, '');
      expect(product.size, '');
      expect(product.rating, 0);
      expect(product.stock, 0);
      expect(product.categoryName, '');
    });

    test('a malformed payload degrades instead of throwing', () {
      final product = Product.fromJson({'name': 'No id or price'});
      expect(product.id, 0);
      expect(product.price, 0);
    });
  });
}
