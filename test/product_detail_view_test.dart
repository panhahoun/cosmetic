import 'package:cosmetic/features/product/product_detail_view.dart';
import 'package:cosmetic/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final product = Product(
    id: 1,
    name: 'Ceramide Cloud Cream',
    description: 'A rich daily moisturizer that repairs the barrier.',
    price: 26.0,
    image: '',
    categoryName: 'Moisturizer',
    brand: 'DermaNest',
    rating: 4.9,
    reviewCount: 390,
    stock: 13,
    size: '50ml',
  );

  testWidgets('ProductDetailView renders without overflow', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: ProductDetailView(product: product),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Ceramide Cloud Cream'), findsOneWidget);
    expect(find.text('Add to Cart'), findsOneWidget);
  });

  testWidgets('Out-of-stock product disables the add button', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final outOfStock = Product(
      id: 2,
      name: 'Empty Jar',
      description: '',
      price: 5.0,
      image: '',
      categoryName: '',
      brand: '',
      rating: 0,
      reviewCount: 0,
      stock: 0,
      size: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: ProductDetailView(product: outOfStock),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Add to Cart'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
