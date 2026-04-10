import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EpiDrawer extends StatelessWidget {
  final String currentRoute;
  final String? userName;
  final String? userRole;
  final String? avatarUrl;

  const EpiDrawer({
    super.key,
    required this.currentRoute,
    this.userName,
    this.userRole,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
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
                    radius: 30,
                    backgroundColor: Colors.white24,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person, size: 30, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 12),
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
                    Text(
                      userRole!,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            _buildItem(context, Icons.dashboard, 'لوحة التحكم', '/dashboard'),
            _buildItem(context, Icons.assignment, 'النماذج', '/forms'),
            _buildItem(context, Icons.upload_file, 'الإرساليات', '/submissions'),
            _buildItem(context, Icons.map, 'الخريطة', '/map'),
            _buildItem(context, Icons.warning_amber, 'النواقص', '/shortages'),
            _buildItem(context, Icons.bar_chart, 'التحليلات', '/analytics'),
            _buildItem(context, Icons.smart_toy, 'المساعد الذكي', '/ai'),
            const Divider(),
            _buildItem(context, Icons.people, 'إدارة المستخدمين', '/admin/users'),
            _buildItem(context, Icons.settings, 'الإعدادات', '/settings'),
            _buildItem(context, Icons.description, 'سجل العمليات', '/audit'),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String title, String route) {
    final isSelected = currentRoute == route;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Tajawal',
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primarySurface,
      onTap: () {
        Navigator.pop(context);
        if (!isSelected) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }
}
