import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Photo Picker Placeholder Tests', () {
    testWidgets('renders camera icon button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add_a_photo),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    });

    testWidgets('renders QR scanner placeholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('مسح QR'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      expect(find.text('مسح QR'), findsOneWidget);
    });
  });
}
