import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dry_shared/epi_shared.dart';
import 'package:epi_supervisor/screens/form_fill/governorate_dropdown.dart';
import 'package:epi_supervisor/screens/form_fill/district_dropdown.dart';

void main() {
  group('GovernorateDropdown', () {
    Widget buildGovDropdown({String? value, bool isRequired = false}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GovernorateDropdown(
              value: value,
              onChanged: (_) {},
              isRequired: isRequired,
            ),
          ),
        ),
      );
    }

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildGovDropdown());
      // Widget should render (may show loading or error depending on providers)
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with required flag', (tester) async {
      await tester.pumpWidget(buildGovDropdown(isRequired: true));
      expect(tester.takeException(), isNull);
    });
  });

  group('DistrictDropdown', () {
    Widget buildDistDropdown(
        {String? govId, String? value, bool isRequired = false}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DistrictDropdown(
              governorateId: govId,
              value: value,
              onChanged: (_) {},
              isRequired: isRequired,
            ),
          ),
        ),
      );
    }

    testWidgets('shows placeholder when no governorate selected',
        (tester) async {
      await tester.pumpWidget(buildDistDropdown(govId: null));
      await tester.pumpAndSettle();

      expect(find.text('اختر المحافظة أولاً'), findsOneWidget);
    });

    testWidgets('renders without crashing when governorate selected',
        (tester) async {
      await tester.pumpWidget(buildDistDropdown(govId: 'some-id'));
      // Should not crash even if providers can't load data
      expect(tester.takeException(), isNull);
    });
  });

  group('Form Field Widgets', () {
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
