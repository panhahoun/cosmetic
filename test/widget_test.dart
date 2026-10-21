import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cosmetic/main.dart';

void main() {
  testWidgets('App boots and shows splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());

    expect(find.text('Cosmetic'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the splash delay finish so no timer is left pending.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(GetMaterialApp), findsOneWidget);
  });
}
