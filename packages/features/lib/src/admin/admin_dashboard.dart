// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

// Admin screens
import 'screens/user_management_screen.dart';
import 'screens/notification_center_screen.dart';
import 'screens/data_management_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/audit_log_screen.dart';
import 'screens/system_monitor_screen.dart';
import 'screens/pages_management_screen.dart';
import 'screens/forms_management_screen.dart';
import 'screens/references_management_screen.dart';
import 'screens/internal_chat_screen.dart';

/// ═══════════════════════════════════════════════════════════════════
///  لوحة التحكم الرئيسية — Admin Dashboard
/// ═══════════════════════════════════════════════════════════════════
///  لوحة تحكم شاملة مع بيانات حقيقية من Supabase
///  إحصائيات مباشرة + رسوم بيانية + موجز النشاط + صحة النظام
/// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════
//  Providers
// ═══════════════════════════════════════════

final dashboardDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = Supabase.instance.client;
  final session = client.auth.currentSession;
  if (session == null) throw Exception('غير مسجل الدخول');

  final response = await client.functions.invoke(
    'get-admin-dashboard',
    body: {},
  );

  if (response.status != 200) {
    throw Exception('فشل تحميل البيانات');
  }

  return Map<String, dynamic>.from(response.data);
});

final realtimeSubmissionsProvider = StreamProvider.autoDispose<int>((ref) {
  final client = Supabase.instance.client;
  return client
      .from('form_submissions')
      .stream(primaryKey: ['id']).map((data) => data.length);
});

// ═══════════════════════════════════════════
//  Main Dashboard Widget
// ═══════════════════════════════════════════

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with TickerProviderStateMixin {
  int _selectedNavIndex = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;
    final dashboardAsync = ref.watch(dashboardDataProvider);

    if (!isWide) return _buildMobileLayout(dashboardAsync);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildMainContent(dashboardAsync)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Sidebar
  // ═══════════════════════════════════════════

  Widget _buildSidebar() {
    final menuItems = [
      _NavItem(Icons.dashboard_rounded, 'لوحة التحكم', 0),
      _NavItem(Icons.description_rounded, 'إدارة الاستمارات', 1),
      _NavItem(Icons.people_alt_rounded, 'إدارة المستخدمين', 2),
      _NavItem(Icons.notifications_active_rounded, 'مركز الإشعارات', 3),
      _NavItem(Icons.storage_rounded, 'إدارة البيانات', 4),
      _NavItem(Icons.assessment_rounded, 'التقارير والتحليلات', 5),
      _NavItem(Icons.settings_rounded, 'الإعدادات', 6),
      _NavItem(Icons.history_rounded, 'سجل التدقيق', 7),
      _NavItem(Icons.monitor_heart_rounded, 'مراقبة النظام', 8),
      _NavItem(Icons.chat_rounded, 'الدردشة الداخلية', 9),
    ];

    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00897B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "EPI Supervisor's",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        'لوحة التحكم الرئيسية',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isSelected = _selectedNavIndex == item.index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.white.withOpacity(0.2))
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        item.icon,
                        color: isSelected ? Colors.white : Colors.white60,
                        size: 22,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () =>
                          setState(() => _selectedNavIndex = item.index),
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'المسؤول',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      Text(
                        'admin',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout_rounded,
                      color: Colors.white.withOpacity(0.6), size: 20),
                  onPressed: () {
                    Supabase.instance.client.auth.signOut();
                  },
                  tooltip: 'تسجيل الخروج',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Main Content Area
  // ═══════════════════════════════════════════

  Widget _buildMainContent(AsyncValue<Map<String, dynamic>> dashboardAsync) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(child: _buildPageContent(dashboardAsync)),
      ],
    );
  }

  /// تبديل المحتوى حسب القسم المختار
  Widget _buildPageContent(AsyncValue<Map<String, dynamic>> dashboardAsync) {
    switch (_selectedNavIndex) {
      case 0:
        return dashboardAsync.when(
          loading: () => _buildLoadingState(),
          error: (err, stack) => _buildErrorState(err),
          data: (data) => _buildDashboardContent(data),
        );
      case 1:
        return const FormsManagementScreen();
      case 2:
        return const UserManagementScreen();
      case 3:
        return const NotificationCenterScreen();
      case 4:
        return const DataManagementScreen();
      case 5:
        return const ReportsScreen();
      case 6:
        return const SettingsScreen();
      case 7:
        return const AuditLogScreen();
      case 8:
        return const SystemMonitorScreen();
      case 9:
        return const InternalChatScreen();
      default:
        return dashboardAsync.when(
          loading: () => _buildLoadingState(),
          error: (err, stack) => _buildErrorState(err),
          data: (data) => _buildDashboardContent(data),
        );
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getScreenTitle(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: Color(0xFF1A2332),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE، d MMMM yyyy', 'ar').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dashboardDataProvider),
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 8),
          // Notifications bell
          Consumer(
            builder: (context, ref, child) {
              final data = ref.watch(dashboardDataProvider).valueOrNull;
              final unread = data?['kpis']?['unread_notifications'] ?? 0;
              return Badge(
                label: Text('$unread'),
                isLabelVisible: unread > 0,
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => setState(() => _selectedNavIndex = 3),
                  tooltip: 'الإشعارات',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getScreenTitle() {
    switch (_selectedNavIndex) {
      case 0:
        return 'لوحة التحكم الرئيسية';
      case 1:
        return 'إدارة الاستمارات';
      case 2:
        return 'إدارة المستخدمين';
      case 3:
        return 'مركز الإشعارات';
      case 4:
        return 'إدارة البيانات';
      case 5:
        return 'التقارير والتحليلات';
      case 6:
        return 'الإعدادات';
      case 7:
        return 'سجل التدقيق';
      case 8:
        return 'مراقبة النظام';
      case 9:
        return 'الدردشة الداخلية';
      default:
        return 'لوحة التحكم';
    }
  }

  // ═══════════════════════════════════════════
  //  Dashboard Content (Main View)
  // ═══════════════════════════════════════════

  Widget _buildDashboardContent(Map<String, dynamic> data) {
    final kpis = Map<String, dynamic>.from(data['kpis'] ?? {});
    final charts = Map<String, dynamic>.from(data['charts'] ?? {});
    final recentActivity =
        List<Map<String, dynamic>>.from(data['recent_activity'] ?? []);
    final systemHealth = Map<String, dynamic>.from(data['system_health'] ?? {});

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardDataProvider);
        await ref.read(dashboardDataProvider.future);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Cards Row
              _buildKPISection(kpis),
              const SizedBox(height: 24),

              // Charts Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline Chart
                  Expanded(
                    flex: 2,
                    child: _buildTimelineChart(
                      List<Map<String, dynamic>>.from(
                          charts['submissions_timeline'] ?? []),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Status Distribution
                  Expanded(
                    child: _buildStatusPieChart(
                      Map<String, dynamic>.from(
                          charts['status_distribution'] ?? {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Governorate Chart + Activity Feed
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildGovernorateChart(
                      List<Map<String, dynamic>>.from(
                          charts['submissions_by_governorate'] ?? []),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildActivityFeed(recentActivity),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // System Health + Quick Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSystemHealth(systemHealth)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildQuickActions(kpis)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  KPI Cards
  // ═══════════════════════════════════════════

  Widget _buildKPISection(Map<String, dynamic> kpis) {
    final cards = [
      _KPICard(
        icon: Icons.people_alt_rounded,
        title: 'إجمالي المستخدمين',
        value: '${kpis['total_users'] ?? 0}',
        subtitle: '${kpis['active_users'] ?? 0} نشط',
        color: const Color(0xFF1E88E5),
        trend: null,
      ),
      _KPICard(
        icon: Icons.description_rounded,
        title: 'إرساليات اليوم',
        value: '${kpis['today_submissions'] ?? 0}',
        subtitle: 'من ${kpis['total_submissions'] ?? 0} إجمالي',
        color: const Color(0xFF43A047),
        trend: kpis['weekly_change_percent'],
      ),
      _KPICard(
        icon: Icons.pending_actions_rounded,
        title: 'بانتظار المراجعة',
        value: '${kpis['pending_submissions'] ?? 0}',
        subtitle: '${kpis['draft_submissions'] ?? 0} مسودة',
        color: const Color(0xFFFB8C00),
        trend: null,
      ),
      _KPICard(
        icon: Icons.warning_rounded,
        title: 'النواقص الحرجة',
        value: '${kpis['critical_shortages'] ?? 0}',
        subtitle: 'من ${kpis['total_shortages'] ?? 0} إجمالي',
        color: const Color(0xFFE53935),
        trend: null,
      ),
      _KPICard(
        icon: Icons.cloud_off_rounded,
        title: 'في الانتظار',
        value: '${kpis['offline_pending'] ?? 0}',
        subtitle: 'مزامنة معلقة',
        color: const Color(0xFF8E24AA),
        trend: null,
      ),
      _KPICard(
        icon: Icons.map_rounded,
        title: 'التغطية الجغرافية',
        value: '${kpis['total_governorates'] ?? 0}',
        subtitle:
            '${kpis['total_districts'] ?? 0} مديرية • ${kpis['total_facilities'] ?? 0} منشأة',
        color: const Color(0xFF00897B),
        trend: null,
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: cards
          .map((card) => SizedBox(
                width: (MediaQuery.of(context).size.width - 280 - 48 - 32) / 3,
                child: card,
              ))
          .toList(),
    );
  }

  // ═══════════════════════════════════════════
  //  Timeline Chart
  // ═══════════════════════════════════════════

  Widget _buildTimelineChart(List<Map<String, dynamic>> timeline) {
    return _DashboardCard(
      title: 'الإرساليات خلال آخر 30 يوم',
      icon: Icons.timeline_rounded,
      child: SizedBox(
        height: 280,
        child: timeline.isEmpty
            ? const Center(child: Text('لا توجد بيانات'))
            : LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getInterval(timeline),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= timeline.length)
                            return const SizedBox();
                          final date = timeline[index]['date'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              date.substring(5),
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    _buildLineData(
                        timeline, 'total', const Color(0xFF00897B), 3),
                    _buildLineData(
                        timeline, 'approved', const Color(0xFF43A047), 2),
                    _buildLineData(
                        timeline, 'pending', const Color(0xFFFB8C00), 2),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) =>
                          touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toInt()}',
                          TextStyle(
                            color: spot.bar.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  LineChartBarData _buildLineData(
    List<Map<String, dynamic>> data,
    String key,
    Color color,
    double strokeWidth,
  ) {
    return LineChartBarData(
      spots: data.asMap().entries.map((entry) {
        return FlSpot(
          entry.key.toDouble(),
          (entry.value[key] ?? 0).toDouble(),
        );
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: strokeWidth,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: strokeWidth > 2,
        color: color.withOpacity(0.1),
      ),
    );
  }

  double _getInterval(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 1;
    final maxVal =
        data.fold<int>(0, (max, e) => math.max(max, (e['total'] ?? 0) as int));
    if (maxVal <= 5) return 1;
    if (maxVal <= 20) return 5;
    if (maxVal <= 50) return 10;
    return (maxVal / 5).ceilToDouble();
  }

  // ═══════════════════════════════════════════
  //  Status Pie Chart
  // ═══════════════════════════════════════════

  Widget _buildStatusPieChart(Map<String, dynamic> distribution) {
    final total =
        distribution.values.fold<int>(0, (sum, v) => sum + (v as int));
    if (total == 0) {
      return _DashboardCard(
        title: 'توزيع الحالات',
        icon: Icons.pie_chart_rounded,
        child: const SizedBox(
            height: 250, child: Center(child: Text('لا توجد بيانات'))),
      );
    }

    final sections = [
      _PieSection('approved', 'مقبول', const Color(0xFF43A047)),
      _PieSection('submitted', 'معلق', const Color(0xFFFB8C00)),
      _PieSection('rejected', 'مرفوض', const Color(0xFFE53935)),
      _PieSection('draft', 'مسودة', const Color(0xFF9E9E9E)),
    ];

    return _DashboardCard(
      title: 'توزيع الحالات',
      icon: Icons.pie_chart_rounded,
      child: SizedBox(
        height: 280,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 50,
                  sections: sections.map((s) {
                    final value = (distribution[s.key] ?? 0).toDouble();
                    return PieChartSectionData(
                      value: value,
                      color: s.color,
                      title: '${(value / total * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      radius: 60,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections.map((s) {
                final value = distribution[s.key] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${s.label} ($value)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Governorate Bar Chart
  // ═══════════════════════════════════════════

  Widget _buildGovernorateChart(List<Map<String, dynamic>> data) {
    return _DashboardCard(
      title: 'الإرساليات حسب المحافظة',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 280,
        child: data.isEmpty
            ? const Center(child: Text('لا توجد بيانات'))
            : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: data
                          .fold<num>(
                              0, (max, e) => math.max(max, e['count'] ?? 0))
                          .toDouble() *
                      1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final name = data[group.x.toInt()]['name'] ?? '';
                        return BarTooltipItem(
                          '$name\n${rod.toY.toInt()}',
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Tajawal'),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length)
                            return const SizedBox();
                          final name = data[index]['name'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              name.length > 6
                                  ? '${name.substring(0, 6)}..'
                                  : name,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getBarInterval(data),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: data.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (entry.value['count'] ?? 0).toDouble(),
                          color: const Color(0xFF00897B),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: (entry.value['count'] ?? 0).toDouble() * 1.3,
                            color: Colors.grey[100],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }

  double _getBarInterval(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 1;
    final maxVal =
        data.fold<num>(0, (max, e) => math.max(max, e['count'] ?? 0));
    if (maxVal <= 5) return 1;
    if (maxVal <= 20) return 5;
    return (maxVal / 4).ceilToDouble();
  }

  // ═══════════════════════════════════════════
  //  Activity Feed
  // ═══════════════════════════════════════════

  Widget _buildActivityFeed(List<Map<String, dynamic>> activities) {
    return _DashboardCard(
      title: 'آخر النشاطات',
      icon: Icons.history_rounded,
      child: SizedBox(
        height: 280,
        child: activities.isEmpty
            ? const Center(child: Text('لا توجد نشاطات'))
            : ListView.separated(
                itemCount: activities.length.clamp(0, 10),
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _buildActivityItem(activity);
                },
              ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final action = activity['action'] as String? ?? '';
    final tableName = activity['table_name'] as String? ?? '';
    final userName = activity['user_name'] as String? ?? 'النظام';
    final createdAt = activity['created_at'] as String? ?? '';

    IconData icon;
    Color color;
    String actionLabel;

    switch (action) {
      case 'create':
        icon = Icons.add_circle_rounded;
        color = const Color(0xFF43A047);
        actionLabel = 'إنشاء';
        break;
      case 'update':
        icon = Icons.edit_rounded;
        color = const Color(0xFF1E88E5);
        actionLabel = 'تعديل';
        break;
      case 'delete':
        icon = Icons.delete_rounded;
        color = const Color(0xFFE53935);
        actionLabel = 'حذف';
        break;
      case 'login':
        icon = Icons.login_rounded;
        color = const Color(0xFF8E24AA);
        actionLabel = 'تسجيل دخول';
        break;
      default:
        icon = Icons.info_rounded;
        color = Colors.grey;
        actionLabel = action;
    }

    final timeDiff = DateTime.now()
        .difference(DateTime.tryParse(createdAt) ?? DateTime.now());
    String timeLabel;
    if (timeDiff.inMinutes < 1) {
      timeLabel = 'الآن';
    } else if (timeDiff.inMinutes < 60) {
      timeLabel = 'منذ ${timeDiff.inMinutes} دقيقة';
    } else if (timeDiff.inHours < 24) {
      timeLabel = 'منذ ${timeDiff.inHours} ساعة';
    } else {
      timeLabel = 'منذ ${timeDiff.inDays} يوم';
    }

    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        '$userName • $actionLabel',
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Tajawal'),
      ),
      subtitle: Text(
        _getTableLabel(tableName),
        style: TextStyle(
            fontSize: 11, color: Colors.grey[500], fontFamily: 'Tajawal'),
      ),
      trailing: Text(
        timeLabel,
        style: TextStyle(
            fontSize: 11, color: Colors.grey[400], fontFamily: 'Tajawal'),
      ),
    );
  }

  String _getTableLabel(String table) {
    switch (table) {
      case 'profiles':
        return 'المستخدمين';
      case 'form_submissions':
        return 'الإرساليات';
      case 'forms':
        return 'الاستمارات';
      case 'supply_shortages':
        return 'النواقص';
      case 'governorates':
        return 'المحافظات';
      case 'districts':
        return 'المديريات';
      default:
        return table;
    }
  }

  // ═══════════════════════════════════════════
  //  System Health
  // ═══════════════════════════════════════════

  Widget _buildSystemHealth(Map<String, dynamic> health) {
    final items = [
      _HealthItem('قاعدة البيانات', health['database'] ?? 'unknown',
          Icons.storage_rounded),
      _HealthItem('خدمة المزامنة', health['sync_service'] ?? 'unknown',
          Icons.sync_rounded),
      _HealthItem('خدمة الذكاء الاصطناعي', health['ai_service'] ?? 'unknown',
          Icons.smart_toy_rounded),
    ];

    return _DashboardCard(
      title: 'صحة النظام',
      icon: Icons.health_and_safety_rounded,
      child: Column(
        children: items.map((item) {
          final isHealthy = item.status == 'healthy';
          final isWarning = item.status == 'warning';
          return ListTile(
            dense: true,
            leading: Icon(
              item.icon,
              color: isHealthy
                  ? const Color(0xFF43A047)
                  : isWarning
                      ? const Color(0xFFFB8C00)
                      : const Color(0xFFE53935),
              size: 22,
            ),
            title: Text(
              item.label,
              style: const TextStyle(fontSize: 14, fontFamily: 'Tajawal'),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (isHealthy
                        ? const Color(0xFF43A047)
                        : isWarning
                            ? const Color(0xFFFB8C00)
                            : const Color(0xFFE53935))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isHealthy
                    ? 'سليم'
                    : isWarning
                        ? 'تحذير'
                        : 'خطأ',
                style: TextStyle(
                  fontSize: 12,
                  color: isHealthy
                      ? const Color(0xFF43A047)
                      : isWarning
                          ? const Color(0xFFFB8C00)
                          : const Color(0xFFE53935),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Quick Actions
  // ═══════════════════════════════════════════

  Widget _buildQuickActions(Map<String, dynamic> kpis) {
    return _DashboardCard(
      title: 'إجراءات سريعة',
      icon: Icons.flash_on_rounded,
      child: Column(
        children: [
          _QuickActionTile(
            icon: Icons.person_add_rounded,
            title: 'إضافة مستخدم جديد',
            color: const Color(0xFF1E88E5),
            onTap: () => setState(() => _selectedNavIndex = 2),
          ),
          _QuickActionTile(
            icon: Icons.send_rounded,
            title: 'إرسال إشعار',
            color: const Color(0xFF8E24AA),
            onTap: () => setState(() => _selectedNavIndex = 3),
          ),
          _QuickActionTile(
            icon: Icons.chat_rounded,
            title: 'الدردشة الداخلية',
            color: const Color(0xFF1E88E5),
            onTap: () => setState(() => _selectedNavIndex = 9),
          ),
          _QuickActionTile(
            icon: Icons.add_chart_rounded,
            title: 'إنشاء استمارة جديدة',
            color: const Color(0xFF00897B),
            onTap: () => setState(() => _selectedNavIndex = 1),
          ),
          _QuickActionTile(
            icon: Icons.download_rounded,
            title: 'تصدير التقارير',
            color: const Color(0xFFFB8C00),
            onTap: () => setState(() => _selectedNavIndex = 5),
          ),
          _QuickActionTile(
            icon: Icons.backup_rounded,
            title: 'نسخ احتياطي',
            color: const Color(0xFF43A047),
            onTap: () => setState(() => _selectedNavIndex = 8),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Loading & Error States
  // ═══════════════════════════════════════════

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 2 * 3.14159,
                child: const Icon(Icons.sync_rounded,
                    size: 48, color: Color(0xFF00897B)),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل البيانات...',
            style: TextStyle(
                fontSize: 16, color: Colors.grey[600], fontFamily: 'Tajawal'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ في تحميل البيانات',
            style: TextStyle(
                fontSize: 18, color: Colors.grey[700], fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: TextStyle(
                fontSize: 13, color: Colors.grey[500], fontFamily: 'Tajawal'),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(dashboardDataProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Mobile Layout
  // ═══════════════════════════════════════════

  Widget _buildMobileLayout(AsyncValue<Map<String, dynamic>> dashboardAsync) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dashboardDataProvider),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => _buildLoadingState(),
        error: (err, stack) => _buildErrorState(err),
        data: (data) {
          final kpis = Map<String, dynamic>.from(data['kpis'] ?? {});
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildKPISection(kpis),
                const SizedBox(height: 16),
                _buildQuickActions(kpis),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex.clamp(0, 4),
        onDestinationSelected: (index) =>
            setState(() => _selectedNavIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.description_rounded), label: 'الاستمارات'),
          NavigationDestination(
              icon: Icon(Icons.people_rounded), label: 'المستخدمين'),
          NavigationDestination(
              icon: Icon(Icons.notifications_rounded), label: 'الإشعارات'),
          NavigationDestination(
              icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  Helper Widgets
// ═══════════════════════════════════════════

class _NavItem {
  final IconData icon;
  final String title;
  final int index;
  const _NavItem(this.icon, this.title, this.index);
}

class _KPICard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final int? trend;

  const _KPICard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (trend! >= 0
                            ? const Color(0xFF43A047)
                            : const Color(0xFFE53935))
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend! >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 16,
                        color: trend! >= 0
                            ? const Color(0xFF43A047)
                            : const Color(0xFFE53935),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trend! >= 0 ? '+' : ''}$trend%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: trend! >= 0
                              ? const Color(0xFF43A047)
                              : const Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Tajawal',
              color: Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF00897B)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: Color(0xFF1A2332),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PieSection {
  final String key;
  final String label;
  final Color color;
  const _PieSection(this.key, this.label, this.color);
}

class _HealthItem {
  final String label;
  final String status;
  final IconData icon;
  const _HealthItem(this.label, this.status, this.icon);
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontFamily: 'Tajawal'),
      ),
      trailing:
          Icon(Icons.arrow_back_ios_rounded, size: 16, color: Colors.grey[400]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
    );
  }
}
