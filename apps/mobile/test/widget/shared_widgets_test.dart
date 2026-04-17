import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dry_shared/epi_shared.dart';

void main() {
  group('EpiButton', () {
    Widget buildButton({
      String text = 'حفظ',
      bool isLoading = false,
      VoidCallback? onPressed,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EpiButton(
              text: text,
              isLoading: isLoading,
              onPressed: onPressed ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders with text', (tester) async {
      await tester.pumpWidget(buildButton(text: 'إرسال'));
      expect(find.text('إرسال'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(buildButton(isLoading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      bool wasPressed = false;
      await tester.pumpWidget(buildButton(onPressed: () => wasPressed = true));

      await tester.tap(find.byType(EpiButton));
      expect(wasPressed, isTrue);
    });

    testWidgets('does not call onPressed when loading', (tester) async {
      bool wasPressed = false;
      await tester.pumpWidget(buildButton(
        isLoading: true,
        onPressed: () => wasPressed = true,
      ));

      await tester.tap(find.byType(EpiButton));
      expect(wasPressed, isFalse);
    });
  });

  group('EpiCard', () {
    Widget buildCard({VoidCallback? onTap}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EpiCard(
              onTap: onTap,
              child: const Text('محتوى البطاقة'),
            ),
          ),
        ),
      );
    }

    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('محتوى البطاقة'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool wasTapped = false;
      await tester.pumpWidget(buildCard(onTap: () => wasTapped = true));

      await tester.tap(find.byType(EpiCard));
      expect(wasTapped, isTrue);
    });
  });

  group('EpiStatusChip', () {
    testWidgets('renders approved status', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EpiStatusChip(status: 'approved'),
            ),
          ),
        ),
      );

      expect(find.text('معتمد'), findsOneWidget);
    });

    testWidgets('renders rejected status', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EpiStatusChip(status: 'rejected'),
            ),
          ),
        ),
      );

      expect(find.text('مرفوض'), findsOneWidget);
    });

    testWidgets('renders submitted status', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EpiStatusChip(status: 'submitted'),
            ),
          ),
        ),
      );

      expect(find.text('مرسل'), findsOneWidget);
    });

    testWidgets('renders unknown status as-is', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EpiStatusChip(status: 'custom_status'),
            ),
          ),
        ),
      );

      expect(find.text('custom_status'), findsOneWidget);
    });
  });

  group('EpiEmptyState', () {
    testWidgets('renders title and icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: Scaffold(
              body: EpiEmptyState(
                icon: Icons.inbox,
                title: 'لا توجد بيانات',
              ),
            ),
          ),
        ),
      );

      expect(find.text('لا توجد بيانات'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: Scaffold(
              body: EpiEmptyState(
                icon: Icons.inbox,
                title: 'فارغ',
                subtitle: 'أضف بيانات جديدة',
              ),
            ),
          ),
        ),
      );

      expect(find.text('فارغ'), findsOneWidget);
      expect(find.text('أضف بيانات جديدة'), findsOneWidget);
    });
  });

  group('EpiLoading', () {
    testWidgets('renders shimmer loading', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EpiLoading.shimmer(),
            ),
          ),
        ),
      );

      // Should render without error
      expect(tester.takeException(), isNull);
    });
  });
}
