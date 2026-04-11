import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EpiStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? trend;
  final bool trendUp;
  final VoidCallback? onTap;

  const EpiStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.trend,
    this.trendUp = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cardColor, size: 24),
                ),
                if (trend != null)
                  Row(
                    children: [
                      Icon(
                        trendUp ? Icons.trending_up : Icons.trending_down,
                        color: trendUp ? AppTheme.successColor : AppTheme.errorColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend!,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: trendUp ? AppTheme.successColor : AppTheme.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
