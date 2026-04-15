import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';

/// Wraps a widget with MaterialApp + ProviderScope + RTL for testing.
Widget testWrapper(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
      // Use a simple theme for tests
      theme: ThemeData(
        fontFamily: 'Tajawal',
        colorSchemeSeed: AppTheme.primaryColor,
      ),
    ),
  );
}

/// Wraps with a Scaffold (for widgets that need one).
Widget testScaffoldWrapper(Widget child) {
  return testWrapper(Scaffold(body: child));
}

/// Pumps the widget and settles all animations.
Future<void> pumpAndSettle(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}
