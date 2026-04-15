import 'package:flutter/material.dart';
import 'package:epi_shared/epi_shared.dart';

/// Signature field — currently text-based, placeholder for future custom painter.
class SignatureField extends StatelessWidget {
  final String? signatureData;
  final ValueChanged<String?> onSignatureChanged;
  final bool isRequired;

  const SignatureField({
    super.key,
    this.signatureData,
    required this.onSignatureChanged,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    final hasSignature = signatureData != null && signatureData!.isNotEmpty;

    return InkWell(
      onTap: () => _openSignaturePad(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: isRequired && !hasSignature
                ? AppTheme.errorColor
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isRequired && !hasSignature
              ? AppTheme.errorColor.withValues(alpha: 0.05)
              : null,
        ),
        child: hasSignature
            ? Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 32, color: AppTheme.successColor),
                        const SizedBox(height: 8),
                        const Text(
                          'تم التوقيع ✓',
                          style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.successColor),
                        ),
                        TextButton(
                          onPressed: () => _openSignaturePad(context),
                          child: const Text('إعادة التوقيع', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.draw,
                    size: 32,
                    color: isRequired && !hasSignature
                        ? AppTheme.errorColor
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'انقر للتوقيع',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: isRequired && !hasSignature
                          ? AppTheme.errorColor
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openSignaturePad(BuildContext context) {
    // TODO: Replace with custom painter signature pad
    final controller = TextEditingController(text: signatureData ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('التوقيع', style: TextStyle(fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اكتب اسمك كتوقيع (سيتم تحسين هذه الميزة لاحقاً بلوحة رسم)',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب اسمك هنا',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                onSignatureChanged(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }
}
