import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dry_shared/dry_shared.dart';

void main() {
  group('Shared Form Widgets', () {
    testWidgets('EpiTextField renders with hint', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EpiTextField(
                hint: 'أدخل الاسم',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('أدخل الاسم'), findsOneWidget);
    });

    testWidgets('EpiTextField accepts text input', (tester) async {
      String? capturedValue;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EpiTextField(
                hint: 'الاسم',
                onChanged: (v) => capturedValue = v,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'أحمد');
      expect(capturedValue, equals('أحمد'));
    });

    testWidgets('EpiTextField shows validation error', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Form(
                key: formKey,
                child: EpiTextField(
                  hint: 'مطلوب',
                  validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                ),
              ),
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('مطلوب'), findsWidgets);
    });
  });
}
