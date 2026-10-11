import 'package:cosmetic/models/product_model.dart';
import 'package:cosmetic/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final product = Product(
    id: 1,
    name: 'Ceramide Cloud Cream Very Long Product Name Here',
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

  testWidgets('ProductCard fits a 0.72-aspect grid cell (194x269)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 194,
            height: 269,
            child: ProductCard(product: product),
          ),
        ),
      ),
    );
    await tester.pump();
    final ex = tester.takeException();
    if (ex != null) {
      fail('ProductCard overflowed: $ex');
    }
  });
}
