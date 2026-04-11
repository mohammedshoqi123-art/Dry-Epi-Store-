import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(dashboardAnalyticsProvider);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: EpiAppBar(
        title: AppStrings.dashboard,
        showBackButton: false,
        actions: [
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
              const SizedBox(height: 20),

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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، $name 👋',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'نظرة عامة على المنصة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.dashboard, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
    final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
    final totalSubmissions = submissions['total'] as int? ?? 0;
    final totalShortages = shortages['total'] as int? ?? 0;
    final resolvedShortages = shortages['resolved'] as int? ?? 0;
    final criticalShortages = (shortages['bySeverity'] as Map<String, dynamic>?)?['critical'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            EpiStatCard(
              title: 'الإرساليات',
              value: '$totalSubmissions',
              icon: Icons.upload_file,
              color: AppTheme.primaryColor,
              onTap: () => context.go('/submissions'),
            ),
            EpiStatCard(
              title: 'النواقص',
              value: '$totalShortages',
              icon: Icons.warning_amber,
              color: AppTheme.warningColor,
              onTap: () => context.push('/admin/audit'),
            ),
            EpiStatCard(
              title: 'النواقص الحرجة',
              value: '$criticalShortages',
              icon: Icons.error_outline,
              color: AppTheme.errorColor,
            ),
            EpiStatCard(
              title: 'النواقص المحلولة',
              value: '$resolvedShortages',
              icon: Icons.check_circle,
              color: AppTheme.successColor,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Status Chart
        const Text(
          'حالة الإرساليات',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildStatusChart(submissions['byStatus'] as Map<String, dynamic>? ?? {}),
        const SizedBox(height: 24),

        // Quick Actions
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildQuickActions(context),
      ],
    );
  }

  Widget _buildStatusChart(Map<String, dynamic> statusData) {
    if (statusData.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text(AppStrings.noData)),
      );
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

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: statusData.entries.map((e) {
                  return PieChartSectionData(
                    value: (e.value as num).toDouble(),
                    color: colors[e.key] ?? Colors.grey,
                    radius: 60,
                    title: '${e.value}',
                    titleStyle: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: statusData.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[e.key],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${labels[e.key] ?? e.key} (${e.value})',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(Icons.add_circle, 'إرسال جديد', '/forms', AppTheme.primaryColor),
      _QuickAction(Icons.map, 'الخريطة', '/map', AppTheme.infoColor),
      _QuickAction(Icons.bar_chart, 'التحليلات', '/analytics', AppTheme.successColor),
      _QuickAction(Icons.smart_toy, 'المساعد', '/ai', AppTheme.secondaryColor),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: actions.map((a) {
        return GestureDetector(
          onTap: () => context.go(a.route),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(a.icon, color: a.color, size: 26),
              ),
              const SizedBox(height: 6),
              Text(
                a.label,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  _QuickAction(this.icon, this.label, this.route, this.color);
}
