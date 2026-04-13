import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EpiStatusChip extends StatelessWidget {
  final String status;
  final String? label;
  final bool small;

  const EpiStatusChip({
    super.key,
    required this.status,
    this.label,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    final text = label ?? _getStatusLabel(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(small ? 6 : 8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'draft': return 'مسودة';
      case 'submitted': return 'مرسل';
      case 'reviewed': return 'قيد المراجعة';
      case 'approved': return 'معتمد';
      case 'rejected': return 'مرفوض';
      case 'critical': return 'حرج';
      case 'high': return 'عالي';
      case 'medium': return 'متوسط';
      case 'low': return 'منخفض';
      default: return status;
    }
  }
}
