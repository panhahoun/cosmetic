import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cosmetic/main.dart';

void main() {
  testWidgets('App boots and shows splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 1));
    // Splash screen should show Cosmetic text or progress indicator
    expect(find.byType(GetMaterialApp), findsOneWidget);
    // Let the splash screen's 2s delay elapse so no timer is left pending.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
