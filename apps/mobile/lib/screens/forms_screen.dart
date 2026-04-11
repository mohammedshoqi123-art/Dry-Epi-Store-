import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';

class FormsScreen extends ConsumerWidget {
  const FormsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forms = ref.watch(formsProvider);

    return Scaffold(
      appBar: const EpiAppBar(
        title: AppStrings.forms,
        showBackButton: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(formsProvider),
        child: forms.when(
          loading: () => const EpiLoading.shimmer(),
          error: (e, _) => EpiErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(formsProvider),
          ),
          data: (data) {
            if (data.isEmpty) {
              return const EpiEmptyState(
                icon: Icons.assignment_outlined,
                title: 'لا توجد نماذج',
                subtitle: 'لم يتم إنشاء نماذج بعد',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final form = data[index];
                return _FormCard(
                  title: form['title_ar'] ?? 'بدون عنوان',
                  description: form['description_ar'],
                  isActive: form['is_active'] ?? false,
                  requiresGps: form['requires_gps'] ?? false,
                  requiresPhoto: form['requires_photo'] ?? false,
                  onTap: () => context.go('/forms/fill/${form['id']}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final String? description;
  final bool isActive;
  final bool requiresGps;
  final bool requiresPhoto;
  final VoidCallback onTap;

  const _FormCard({
    required this.title,
    this.description,
    required this.isActive,
    required this.requiresGps,
    required this.requiresPhoto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EpiCard(
      onTap: isActive ? onTap : null,
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description != null)
                        Text(
                          description!,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (isActive)
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textHint),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (requiresGps) _buildBadge(Icons.location_on, 'GPS'),
                if (requiresPhoto) _buildBadge(Icons.camera_alt, 'صور'),
                if (!isActive) _buildBadge(Icons.block, 'غير نشط', color: AppTheme.errorColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, {Color color = AppTheme.primaryColor}) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
