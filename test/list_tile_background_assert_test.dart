import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ListTile behind a plain opaque Container triggers the hidden-background assert',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              color: Colors.white,
              child: ListTile(title: const Text('item'), onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNotNull);
    },
  );

  testWidgets(
    'ListTile on its own Material with color does not trigger the assert',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Color(0x05000000))],
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(title: const Text('item'), onTap: () {}),
                    const Divider(height: 1),
                    ListTile(title: const Text('item 2'), onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
