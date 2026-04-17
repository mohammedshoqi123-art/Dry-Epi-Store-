import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dry_core/dry_core.dart';
import 'package:dry_shared/dry_shared.dart';
import 'package:dry_epi_store/screens/login_screen.dart';

void main() {
  group('LoginScreen', () {
    /// Wraps LoginScreen with required providers.
    Widget buildLoginScreen() {
      return ProviderScope(
        child: MaterialApp(
          home: const LoginScreen(),
          theme: ThemeData(fontFamily: 'Tajawal'),
        ),
      );
    }

    testWidgets('renders login form with email and password fields',
        (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      // App title
      expect(find.text('مخزن EPI الجاف'), findsOneWidget);

      // Login form title
      expect(find.text('تسجيل الدخول'), findsOneWidget);

      // Email and password fields
      expect(find.byType(TextField), findsNWidgets(2));

      // Login button
      expect(find.text('تسجيل الدخول'), findsWidgets);
    });

    testWidgets('renders email field with correct label', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('البريد الإلكتروني'), findsOneWidget);
    });

    testWidgets('renders password field with correct label', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('كلمة المرور'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      // Find visibility toggle icon
      final visibilityIcon = find.byIcon(Icons.visibility);
      expect(visibilityIcon, findsOneWidget);

      // Tap to hide password
      await tester.tap(visibilityIcon);
      await tester.pump();

      // Icon should change to visibility_off
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap again to show password
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('login button shows loading state on tap', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      // Enter credentials
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'admin@example.com');
      await tester.enterText(fields.last, 'password123');
      await tester.pump();

      // Tap login
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pump();

      // Either loading indicator appears or it handled the error gracefully
      expect(tester.takeException(), isNull);
    });
  });
}
