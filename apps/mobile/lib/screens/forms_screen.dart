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
      appBar: EpiAppBar(
        title: AppStrings.forms,
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => context.go('/forms/status'),
            tooltip: 'حالة الاستمارات',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Clear cache first to force fresh fetch from server
          await ref.read(forceRefreshProvider)('forms');
          ref.invalidate(formsProvider);
        },
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
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 400 + (index * 80)),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: _FormCard(
                    title: form['title_ar'] ?? 'بدون عنوان',
                    description: form['description_ar'],
                    isActive: form['is_active'] ?? false,
                    requiresGps: form['requires_gps'] ?? false,
                    requiresPhoto: form['requires_photo'] ?? false,
                    version: form['version'] ?? 1,
                    onTap: () => context.go('/forms/fill/${form['id']}'),
                  ),
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
  final int version;
  final VoidCallback onTap;

  const _FormCard({
    required this.title,
    this.description,
    required this.isActive,
    required this.requiresGps,
    required this.requiresPhoto,
    required this.version,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: EpiCard(
          onTap: isActive ? onTap : null,
          child: Opacity(
            opacity: isActive ? 1.0 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryDark])
                            : null,
                        color: isActive ? null : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.assignment_rounded,
                        color: isActive ? Colors.white : Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (description != null && description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                description!,
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryColor),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (requiresGps) _buildBadge(Icons.location_on, 'GPS', AppTheme.infoColor),
                    if (requiresPhoto) _buildBadge(Icons.camera_alt, 'صور', AppTheme.secondaryColor),
                    if (!isActive) _buildBadge(Icons.block, 'غير نشط', AppTheme.errorColor),
                    const Spacer(),
                    Text(
                      'v$version',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
