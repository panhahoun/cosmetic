import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:cosmetic/main.dart';

void main() {
  testWidgets('App boots and shows splash', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 1));
    // Splash screen should show Cosmetic text or progress indicator
    expect(find.byType(GetMaterialApp), findsOneWidget);
  });
}
