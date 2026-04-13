import 'package:flutter/material.dart';

/// Visual indicator showing the save/sync status of a form submission.
/// Shows: saving → saved locally → synced to server.
///
/// Usage in form screens:
/// ```dart
/// SaveStatusIndicator(
///   isSaving: _isLoading,
///   savedLocally: _wasSavedLocally,
///   synced: _wasSynced,
/// )
/// ```
class SaveStatusIndicator extends StatelessWidget {
  final bool isSaving;
  final bool savedLocally;
  final bool synced;

  const SaveStatusIndicator({
    super.key,
    required this.isSaving,
    required this.savedLocally,
    required this.synced,
  });

  @override
  Widget build(BuildContext context) {
    if (isSaving) {
      return _buildChip(
        icon: Icons.hourglass_empty,
        label: 'جاري الحفظ...',
        color: Colors.orange,
      );
    }
    if (synced) {
      return _buildChip(
        icon: Icons.cloud_done,
        label: 'متزامن مع السيرفر',
        color: Colors.green,
      );
    }
    if (savedLocally) {
      return _buildChip(
        icon: Icons.save_outlined,
        label: 'محفوظ محلياً — في انتظار المزامنة',
        color: Colors.blue,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
