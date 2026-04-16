import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EpiDialog extends StatelessWidget {
  final String title;
  final String? content;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;
  final Color? iconColor;
  final bool isDanger;

  const EpiDialog({
    super.key,
    required this.title,
    this.content,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.icon,
    this.iconColor,
    this.isDanger = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? content,
    String? confirmText,
    String? cancelText,
    bool isDanger = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EpiDialog(
        title: title,
        content: content,
        confirmText: confirmText ?? 'تأكيد',
        cancelText: cancelText ?? 'إلغاء',
        isDanger: isDanger,
        icon: icon,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon,
                color: iconColor ??
                    (isDanger ? AppTheme.errorColor : AppTheme.primaryColor)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 18),
            ),
          ),
        ],
      ),
      content: content != null
          ? Text(content!, style: const TextStyle(fontFamily: 'Tajawal'))
          : null,
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: onCancel ?? () => Navigator.of(context).pop(),
            child: Text(cancelText!),
          ),
        if (confirmText != null)
          ElevatedButton(
            onPressed: onConfirm,
            style: isDanger
                ? ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor)
                : null,
            child: Text(confirmText!),
          ),
      ],
    );
  }
}
