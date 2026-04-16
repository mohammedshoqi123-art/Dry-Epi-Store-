import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:epi_core/epi_core.dart';
import '../providers/app_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final authState = authAsync.valueOrNull;

    if (authState == null || !authState.isAuthenticated) {
      return Scaffold(
        appBar: EpiAppBar(title: 'البروفايل', showBackButton: true),
        body: const EpiEmptyState(
          icon: Icons.person_off,
          title: 'غير مسجل الدخول',
        ),
      );
    }

    final role = authState.role;
    final governoratesAsync = ref.watch(governoratesProvider);

    return Scaffold(
      appBar: EpiAppBar(title: 'البروفايل', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                _getInitials(authState.fullName ?? ''),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Full Name
            Text(
              authState.fullName ?? 'مستخدم',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),

            // Role badge
            if (role != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.nameAr,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // Info cards
            _InfoTile(
              icon: Icons.email_outlined,
              label: 'البريد الإلكتروني',
              value: authState.email ?? 'غير محدد',
            ),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'رقم الجوال',
              value: authState.phone ?? 'غير محدد',
            ),
            _InfoTile(
              icon: Icons.badge_outlined,
              label: 'الصفة',
              value: role?.nameAr ?? 'غير محدد',
            ),

            // Governorate & District (resolve names from IDs)
            governoratesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (governorates) {
                final govName = governorates
                    .where((g) => g['id'] == authState.governorateId)
                    .map((g) => g['name_ar'] as String)
                    .firstOrNull;

                return Column(
                  children: [
                    _InfoTile(
                      icon: Icons.location_city,
                      label: 'المحافظة',
                      value: govName ?? 'غير محدد',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // App version
            Text(
              'الإصدار ${AppConfig.appVersion}',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
