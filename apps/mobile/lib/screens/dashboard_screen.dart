import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:epi_core/epi_core.dart';
import '../providers/app_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();

    // ═══ FIX: Ensure auto-sync starts on dashboard load ═══
    // The SyncService provider is lazy — it only initializes when first read.
    // Reading it here guarantees auto-sync is active after login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider.future).then((service) {
        // Trigger immediate sync if there are pending items
        if (service.currentState.pendingCount > 0) {
          service.sync().catchError((_) {});
        }
      }).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(dashboardAnalyticsProvider);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: EpiAppBar(
        title: AppStrings.dashboard,
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportDashboardPDF,
            tooltip: 'تقرير PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardAnalyticsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardAnalyticsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              authState.when(
                data: (state) => _buildWelcome(state.fullName ?? 'مستخدم'),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 12),

              // Pending sync banner
              _buildPendingSyncBanner(),
              const SizedBox(height: 12),

              // Stats Grid
              analytics.when(
                loading: () => const EpiLoading.shimmer(),
                error: (e, _) => EpiErrorWidget(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(dashboardAnalyticsProvider),
                ),
                data: (data) => _buildDashboard(context, ref, data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'صباح الخير' : hour < 17 ? 'مساء الخير' : 'مساء الخير';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
                    '$greeting، $name 👋',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDateString(),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
                    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return '${days[now.weekday - 1]}، ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _buildPendingSyncBanner() {
    final pendingAsync = ref.watch(syncPendingCountProvider);
    return pendingAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, color: Colors.orange.shade700, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$count استمارة بانتظار المزامنة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(syncServiceProvider.future).then((s) => s.sync().catchError((_) {}));
                },
                child: Text('مزامنة الآن', style: TextStyle(color: Colors.orange.shade800)),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
    final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
    final totalSubmissions = submissions['total'] as int? ?? 0;
    final todaySubmissions = submissions['today'] as int? ?? 0;
    final totalShortages = shortages['total'] as int? ?? 0;
    final resolvedShortages = shortages['resolved'] as int? ?? 0;
    final criticalShortages = (shortages['bySeverity'] as Map<String, dynamic>?)?['critical'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Cards - staggered animation
        ...List.generate(4, (i) {
          final cards = [
            _StatCardData('الإرساليات', '$totalSubmissions', 'اليوم: $todaySubmissions', Icons.upload_file, AppTheme.primaryColor),
            _StatCardData('النواقص', '$totalShortages', 'محلول: $resolvedShortages', Icons.warning_amber, AppTheme.warningColor),
            _StatCardData('النواقص الحرجة', '$criticalShortages', criticalShortages > 0 ? 'يحتاج انتباه!' : 'لا توجد', Icons.error_outline, AppTheme.errorColor),
            _StatCardData('الإنجاز', totalShortages > 0 ? '${(resolvedShortages / totalShortages * 100).toStringAsFixed(0)}%' : '0%', 'نسبة الحل', Icons.check_circle, AppTheme.successColor),
          ];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + (i * 100)),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(offset: Offset(0, 15 * (1 - value)), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildModernStatCard(cards[i]),
            ),
          );
        }),
        const SizedBox(height: 8),

        // Status Chart
        _sectionTitle('حالة الإرساليات'),
        const SizedBox(height: 12),
        _buildStatusChart(submissions['byStatus'] as Map<String, dynamic>? ?? {}),
        const SizedBox(height: 24),

        // Trend Line Chart (byDay)
        _sectionTitle('الاتجاه الأسبوعي'),
        const SizedBox(height: 12),
        _buildTrendChart(submissions['byDay'] as Map<String, dynamic>? ?? {}),
        const SizedBox(height: 24),

        // Quick Actions
        _sectionTitle('إجراءات سريعة'),
        const SizedBox(height: 12),
        _buildQuickActions(context),
      ],
    );
  }

  Widget _buildModernStatCard(_StatCardData card) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: card.color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(card.icon, color: card.color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  card.value,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w700, color: card.color),
                ),
              ],
            ),
          ),
          Text(
            card.subtitle,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildStatusChart(Map<String, dynamic> statusData) {
    if (statusData.isEmpty) {
      return _emptyChart('لا توجد بيانات');
    }

    final colors = {
      'draft': Colors.grey,
      'submitted': AppTheme.infoColor,
      'reviewed': AppTheme.warningColor,
      'approved': AppTheme.successColor,
      'rejected': AppTheme.errorColor,
    };

    final labels = {
      'draft': 'مسودة',
      'submitted': 'مرسل',
      'reviewed': 'مراجعة',
      'approved': 'معتمد',
      'rejected': 'مرفوض',
    };

    final total = statusData.values.fold<int>(0, (sum, v) => sum + (v as int));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sections: statusData.entries.map((e) {
                  final pct = total > 0 ? (e.value as int) / total * 100 : 0;
                  return PieChartSectionData(
                    value: (e.value as num).toDouble(),
                    color: colors[e.key] ?? Colors.grey,
                    radius: 50,
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 3,
                centerSpaceRadius: 25,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: statusData.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[e.key],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        labels[e.key] ?? e.key,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '${e.value}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(Map<String, dynamic> dayData) {
    if (dayData.isEmpty) return _emptyChart('لا توجد بيانات اتجاه');

    final entries = dayData.entries.toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i >= 0 && i < entries.length && i % 2 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        entries[i].key,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppTheme.textHint),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: entries.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), (e.value.value as num).toDouble());
              }).toList(),
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyChart(String message) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 36, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(Icons.add_circle_outline, 'إرسال جديد', '/forms', AppTheme.primaryColor),
      _QuickAction(Icons.map_outlined, 'الخريطة', '/map', AppTheme.infoColor),
      _QuickAction(Icons.bar_chart_outlined, 'التحليلات', '/analytics', AppTheme.successColor),
      _QuickAction(Icons.smart_toy_outlined, 'المساعد', '/ai', AppTheme.secondaryColor),
    ];

    return Row(
      children: actions.map((a) {
        return Expanded(
          child: GestureDetector(
            onTap: () => context.go(a.route),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: a.color.withValues(alpha: 0.08), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(a.icon, color: a.color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.label,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: a.color, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _exportDashboardPDF() async {
    final analytics = ref.read(dashboardAnalyticsProvider);
    analytics.whenData((data) async {
      final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
      final byStatus = submissions['byStatus'] as Map<String, dynamic>? ?? {};

      try {
        if (mounted) context.showInfo('جارٍ إنشاء التقرير...');

        final file = await ReportGenerator.generatePDFReport(
          title: 'تقرير لوحة التحكم — منصة مشرف EPI',
          period: 'الشهر الحالي',
          submissions: [],
          stats: {
            'total': submissions['total'] ?? 0,
            'today': submissions['today'] ?? 0,
            'completionRate': submissions['completionRate'] ?? 0,
            'rejected': byStatus['rejected'] ?? 0,
            'pending': byStatus['draft'] ?? 0,
            'byStatus': byStatus,
          },
          recommendations: LocalAnalyticsEngine.generateInsights(data),
        );

        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          subject: 'تقرير لوحة التحكم EPI',
        ));
      } catch (e) {
        if (mounted) context.showError('فشل إنشاء التقرير: $e');
      }
    });
  }
}

class _StatCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  _StatCardData(this.title, this.value, this.subtitle, this.icon, this.color);
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  _QuickAction(this.icon, this.label, this.route, this.color);
}
