import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EpiErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const EpiErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
