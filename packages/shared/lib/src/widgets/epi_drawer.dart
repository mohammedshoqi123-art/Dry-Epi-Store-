import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EpiDrawer extends StatelessWidget {
  final String currentRoute;
  final String? userName;
  final String? userRole;
  final String? avatarUrl;
  final int userRoleLevel;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onLogout;
  final VoidCallback? onSyncConfig;
  final bool isSyncingConfig;

  const EpiDrawer({
    super.key,
    required this.currentRoute,
    this.userName,
    this.userRole,
    this.avatarUrl,
    this.userRoleLevel = 1,
    this.onNavigate,
    this.onLogout,
    this.onSyncConfig,
    this.isSyncingConfig = false,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                    child: avatarUrl == null
                        ? Text(
                            (userName ?? 'م')[0],
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    userName ?? 'مستخدم',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (userRole != null)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        userRole!,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _SectionLabel(label: 'الرئيسية'),
                  _buildItem(context, Icons.dashboard_rounded, 'لوحة التحكم', '/dashboard'),
                  _buildItem(context, Icons.assignment_rounded, 'النماذج', '/forms'),
                  _buildItem(context, Icons.dashboard_customize_outlined, 'حالة الاستمارات', '/forms/status'),
                  _buildItem(context, Icons.upload_file_rounded, 'الإرساليات', '/submissions'),
                  _buildItem(context, Icons.map_rounded, 'الخريطة', '/map'),
                  _buildItem(context, Icons.notifications_rounded, 'الإشعارات', '/notifications'),
                  _buildItem(context, Icons.chat_rounded, 'الشات الداخلي', '/chat'),

                  // References — visible to all roles
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(height: 1),
                  ),
                  _SectionLabel(label: 'الموارد'),
                  _buildItem(context, Icons.menu_book_rounded, 'المراجع والكتب', '/references'),

                  // Analytics & AI — visible to all roles
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(height: 1),
                  ),
                  _SectionLabel(label: 'التحليلات والذكاء'),
                  _buildItem(context, Icons.bar_chart_rounded, 'التقارير', '/analytics'),
                  _buildItem(context, Icons.smart_toy_rounded, 'المساعد الذكي', '/ai'),
                  _buildItem(context, Icons.person_rounded, 'البروفايل', '/profile'),
                ],
              ),
            ),

            // Sync Config + Logout
            const Divider(height: 1),
            // ═══ مزامنة تكوين — clear cache and reload fresh data from server ═══
            if (onSyncConfig != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: isSyncingConfig
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.infoColor),
                          )
                        : const Icon(Icons.sync_rounded, color: AppTheme.infoColor, size: 20),
                  ),
                  title: Text(
                    isSyncingConfig ? 'جاري المزامنة...' : 'مزامنة تكوين',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppTheme.infoColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text(
                    'جلب أحدث النماذج والاستمارات',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint),
                  ),
                  onTap: isSyncingConfig ? null : () {
                    Navigator.pop(context);
                    onSyncConfig?.call();
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 20),
                ),
                title: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.errorColor, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onLogout?.call();
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String title, String route) {
    final isSelected = currentRoute.startsWith(route);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppTheme.primarySurface.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
        onTap: () {
          Navigator.pop(context);
          if (!isSelected && onNavigate != null) {
            onNavigate!(route);
          }
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textHint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
