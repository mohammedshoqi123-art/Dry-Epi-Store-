import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Admin menu item for sidebar navigation
class AdminMenuItem {
  final IconData icon;
  final String title;
  final String route;
  final String? badge;

  const AdminMenuItem({
    required this.icon,
    required this.title,
    required this.route,
    this.badge,
  });
}

/// Full-featured admin dashboard with sidebar navigation.
/// Designed for web/tablet with responsive layout.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<AdminMenuItem> _menuItems = const [
    AdminMenuItem(
      icon: Icons.dashboard_rounded,
      title: 'لوحة التحكم',
      route: '/dashboard',
    ),
    AdminMenuItem(
      icon: Icons.description_rounded,
      title: 'إدارة الاستمارات',
      route: '/admin/forms',
    ),
    AdminMenuItem(
      icon: Icons.people_rounded,
      title: 'إدارة المستخدمين',
      route: '/admin/users',
    ),
    AdminMenuItem(
      icon: Icons.analytics_rounded,
      title: 'التحليلات',
      route: '/analytics',
    ),
    AdminMenuItem(
      icon: Icons.history_rounded,
      title: 'سجل التدقيق',
      route: '/admin/audit',
    ),
    AdminMenuItem(
      icon: Icons.dashboard_customize_rounded,
      title: 'إدارة الصفحات',
      route: '/admin/pages',
    ),
    AdminMenuItem(
      icon: Icons.map_rounded,
      title: 'الخريطة',
      route: '/map',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    if (!isWide) {
      // Mobile layout: use bottom navigation
      return _buildMobileLayout();
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Main content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          const Divider(height: 1),
          Expanded(child: _buildMenuList()),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shield_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مشرف EPI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      'لوحة الإدارة',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        final isSelected = index == _selectedIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() => _selectedIndex = index);
                context.go(item.route);
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[800],
                        ),
                      ),
                    ),
                    if (item.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Icon(
              Icons.person,
              size: 18,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المسؤول',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  'admin',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout, size: 18, color: Colors.grey[500]),
            onPressed: () => context.go('/login'),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContentHeader(),
          const SizedBox(height: 24),
          Expanded(child: _buildDashboardCards()),
        ],
      ),
    );
  }

  Widget _buildContentHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _menuItems[_selectedIndex].title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'مرحباً بك في لوحة إدارة منصة مشرف EPI',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Quick actions
        IconButton.filled(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'الإشعارات',
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: () {},
          icon: const Icon(Icons.refresh),
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildDashboardCards() {
    final cards = [
      _DashboardCardData(
        icon: Icons.people_rounded,
        title: 'المستخدمون النشطون',
        value: '24',
        subtitle: '+3 هذا الأسبوع',
        color: Colors.blue,
        trend: Trend.up,
      ),
      _DashboardCardData(
        icon: Icons.description_rounded,
        title: 'الإرساليات اليوم',
        value: '156',
        subtitle: '85% معدل الإنجاز',
        color: Colors.green,
        trend: Trend.up,
      ),
      _DashboardCardData(
        icon: Icons.warning_rounded,
        title: 'النواقص الحرجة',
        value: '7',
        subtitle: 'تحتاج معالجة فورية',
        color: Colors.orange,
        trend: Trend.down,
      ),
      _DashboardCardData(
        icon: Icons.cloud_off_rounded,
        title: 'في الانتظار',
        value: '12',
        subtitle: 'بانتظار المزامنة',
        color: Colors.purple,
        trend: Trend.stable,
      ),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => _buildStatCard(cards[index]),
    );
  }

  Widget _buildStatCard(_DashboardCardData data) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: data.color.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(data.icon, color: data.color, size: 22),
                ),
                const Spacer(),
                Icon(
                  data.trend == Trend.up
                      ? Icons.trending_up
                      : data.trend == Trend.down
                          ? Icons.trending_down
                          : Icons.trending_flat,
                  color: data.trend == Trend.up
                      ? Colors.green
                      : data.trend == Trend.down
                          ? Colors.red
                          : Colors.grey,
                  size: 20,
                ),
              ],
            ),
            const Spacer(),
            Text(
              data.value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_menuItems[_selectedIndex].title),
        centerTitle: true,
      ),
      body: _buildDashboardCards().paddingAll(16),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex.clamp(0, 4),
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          context.go(_menuItems[index].route);
        },
        destinations: _menuItems
            .take(5)
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  label: item.title,
                ))
            .toList(),
      ),
    );
  }
}

enum Trend { up, down, stable }

class _DashboardCardData {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final Trend trend;

  _DashboardCardData({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.trend,
  });
}

extension _Padding on Widget {
  Widget paddingAll(double padding) => Padding(
        padding: EdgeInsets.all(padding),
        child: this,
      );
}
