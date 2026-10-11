import 'package:cosmetic/data/wishlist_service_dio.dart';
import 'package:cosmetic/features/wishlist/wishlist_controller.dart';
import 'package:cosmetic/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeWishlistService implements WishlistService {
  final Set<int> favoriteIds = {};
  final List<Product> catalog;

  FakeWishlistService(this.catalog);

  int? lastAdded;
  int? lastRemoved;

  @override
  Future<List<Product>> getWishlist() async {
    return catalog.where((p) => favoriteIds.contains(p.id)).toList();
  }

  @override
  Future<void> addToWishlist(int productId) async {
    lastAdded = productId;
    favoriteIds.add(productId);
  }

  @override
  Future<void> removeFromWishlist(int productId) async {
    lastRemoved = productId;
    favoriteIds.remove(productId);
  }
}

void main() {
  final product = Product(
    id: 1,
    name: 'Ceramide Cloud Cream',
    description: 'Moisturizer',
    price: 26.0,
    image: '',
    categoryName: 'Moisturizer',
    brand: 'DermaNest',
    rating: 4.9,
    reviewCount: 390,
    stock: 13,
    size: '50ml',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'id': 7});
  });

  tearDown(() => Get.reset());

  Future<void> pumpController(
    WidgetTester tester,
    WishlistController controller,
  ) async {
    await tester.pumpWidget(GetMaterialApp(home: const Scaffold()));
    await controller.reload();
    await tester.pump();
  }

  /// Lets the toggle snackbar show, expire and animate away so no timer or
  /// ticker is left running when the test tears the tree down.
  Future<void> settleSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('refresh loads the server wishlist for a logged-in user',
      (tester) async {
    final service = FakeWishlistService([product]);
    service.favoriteIds.add(1);
    final controller = WishlistController(service: service);
    addTearDown(controller.dispose);

    await pumpController(tester, controller);

    expect(controller.currentUserId.value, 7);
    expect(controller.items, hasLength(1));
    expect(controller.isFavorite(1), isTrue);
  });

  testWidgets('toggle adds a favorite then removes it', (tester) async {
    final service = FakeWishlistService([product]);
    final controller = WishlistController(service: service);
    addTearDown(controller.dispose);

    await pumpController(tester, controller);
    expect(controller.isFavorite(1), isFalse);

    await controller.toggle(product);
    await tester.pump();
    expect(controller.isFavorite(1), isTrue);
    expect(controller.items, hasLength(1));
    expect(service.lastAdded, 1);
    expect(service.favoriteIds.contains(1), isTrue);
    await settleSnackbars(tester);

    await controller.toggle(product);
    await tester.pump();
    expect(controller.isFavorite(1), isFalse);
    expect(controller.items, isEmpty);
    expect(service.lastRemoved, 1);
    expect(service.favoriteIds.contains(1), isFalse);
    await settleSnackbars(tester);
  });

  testWidgets('toggle for a logged-out user changes nothing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = FakeWishlistService([product]);
    final controller = WishlistController(service: service);
    addTearDown(controller.dispose);

    await pumpController(tester, controller);
    expect(controller.currentUserId.value, 0);

    await controller.toggle(product);
    await tester.pump();
    expect(controller.isFavorite(1), isFalse);
    expect(controller.items, isEmpty);
    expect(service.lastAdded, isNull);
    await settleSnackbars(tester);
  });
}