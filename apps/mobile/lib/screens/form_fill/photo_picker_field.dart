import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:epi_shared/epi_shared.dart';

/// Photo picker field — camera or gallery, with preview grid and delete.
class PhotoPickerField extends StatelessWidget {
  final List<XFile> photos;
  final int maxPhotos;
  final ValueChanged<List<XFile>> onPhotosChanged;
  final bool isRequired;

  const PhotoPickerField({
    super.key,
    required this.photos,
    required this.maxPhotos,
    required this.onPhotosChanged,
    required this.isRequired,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (picked != null) {
        final updated = List<XFile>.from(photos)..add(picked);
        onPhotosChanged(updated);
      }
    } catch (e) {
      if (context.mounted) context.showError('فشل التقاط الصورة');
    }
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('الكاميرا', style: TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('المعرض', style: TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo grid
        if (photos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Stack(
                    children: [
                      XFileImage(
                        file: photos[index],
                        width: 100,
                        height: 100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            final updated = List<XFile>.from(photos)..removeAt(index);
                            onPhotosChanged(updated);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.errorColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (photos.isNotEmpty) const SizedBox(height: 8),
        // Add button
        if (photos.length < maxPhotos)
          InkWell(
            onTap: () => _showPickerOptions(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isRequired && photos.isEmpty
                      ? AppTheme.errorColor
                      : Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isRequired && photos.isEmpty
                    ? AppTheme.errorColor.withValues(alpha: 0.05)
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: 32,
                    color: isRequired && photos.isEmpty
                        ? AppTheme.errorColor
                        : AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    photos.isEmpty
                        ? 'انقر لإرفاق صورة (${photos.length}/$maxPhotos)'
                        : 'إضافة صورة أخرى (${photos.length}/$maxPhotos)',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: isRequired && photos.isEmpty
                          ? AppTheme.errorColor
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
