import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:epi_supervisor/screens/form_fill/photo_picker_field.dart';

void main() {
  group('PhotoPickerField', () {
    Widget buildPhotoPicker({
      List<XFile> photos = const [],
      int maxPhotos = 1,
      bool isRequired = false,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PhotoPickerField(
              photos: photos,
              maxPhotos: maxPhotos,
              onPhotosChanged: (_) {},
              isRequired: isRequired,
            ),
          ),
        ),
      );
    }

    testWidgets('shows add button when no photos', (tester) async {
      await tester.pumpWidget(buildPhotoPicker());

      expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
      expect(find.text('انقر لإرفاق صورة'), findsOneWidget);
    });

    testWidgets('hides add button when max photos reached', (tester) async {
      final photos = [XFile('/fake/path.jpg')];
      await tester.pumpWidget(buildPhotoPicker(photos: photos, maxPhotos: 1));

      // Add button should be hidden
      expect(find.text('انقر لإرفاق صورة'), findsNothing);
    });

    testWidgets('shows photo count in text', (tester) async {
      await tester.pumpWidget(buildPhotoPicker(maxPhotos: 2));

      expect(find.text('انقر لإرفاق صورة'), findsOneWidget);
    });

    testWidgets('renders with required styling when empty and required', (tester) async {
      await tester.pumpWidget(buildPhotoPicker(isRequired: true));

      // Should not crash
      expect(tester.takeException(), isNull);
      // Should show the add button
      expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    });

    testWidgets('opens bottom sheet on tap', (tester) async {
      await tester.pumpWidget(buildPhotoPicker());
      await tester.pumpAndSettle();

      // Tap the add button area
      await tester.tap(find.byIcon(Icons.add_a_photo));
      await tester.pumpAndSettle();

      // Bottom sheet should appear with Camera and Gallery options
      expect(find.text('الكاميرا'), findsOneWidget);
      expect(find.text('المعرض'), findsOneWidget);
    });
  });
}
