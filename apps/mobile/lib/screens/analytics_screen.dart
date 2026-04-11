import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // ignore: unused_field — reserved for future period filtering
  String _selectedPeriod = '30d';

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(dashboardAnalyticsProvider);

    return Scaffold(
      appBar: EpiAppBar(
        title: AppStrings.analytics,
        showBackButton: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _selectedPeriod = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '7d', child: Text('آخر 7 أيام')),
              const PopupMenuItem(value: '30d', child: Text('آخر 30 يوم')),
              const PopupMenuItem(value: '90d', child: Text('آخر 90 يوم')),
            ],
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.calendar_today),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardAnalyticsProvider),
        child: analytics.when(
          loading: () => EpiLoading.shimmer(),
          error: (e, _) => EpiErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(dashboardAnalyticsProvider),
          ),
          data: (data) => _buildAnalytics(data),
        ),
      ),
    );
  }

  Widget _buildAnalytics(Map<String, dynamic> data) {
    final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
    final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
    final byGovernorate = submissions['byGovernorate'] as Map<String, dynamic>? ?? {};
    final byStatus = submissions['byStatus'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          Row(
            children: [
              Expanded(child: _kpiCard('إجمالي الإرساليات', '${submissions['total'] ?? 0}', Icons.upload_file, AppTheme.primaryColor)),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('النواقص النشطة', '${shortages['unresolved'] ?? 0}', Icons.warning, AppTheme.warningColor)),
            ],
          ),
          const SizedBox(height: 24),

          // Status Bar Chart
          _sectionTitle('توزيع الحالات'),
          const SizedBox(height: 12),
          _buildStatusBarChart(byStatus),
          const SizedBox(height: 24),

          // Governorate Bar Chart
          _sectionTitle('الإرساليات حسب المحافظة'),
          const SizedBox(height: 12),
          _buildGovernorateChart(byGovernorate),
          const SizedBox(height: 24),

          // Shortages by Severity
          _sectionTitle('النواقص حسب الخطورة'),
          const SizedBox(height: 12),
          _buildSeverityChart(shortages),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          Text(title,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600));
  }

  Widget _buildStatusBarChart(Map<String, dynamic> data) {
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text(AppStrings.noData)));

    final labels = {'draft': 'مسودة', 'submitted': 'مرسل', 'reviewed': 'مراجعة', 'approved': 'معتمد', 'rejected': 'مرفوض'};
    final colors = {'draft': Colors.grey, 'submitted': AppTheme.infoColor, 'reviewed': AppTheme.warningColor, 'approved': AppTheme.successColor, 'rejected': AppTheme.errorColor};

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: data.entries.toList().asMap().entries.map((e) {
            final key = e.value.key;
            final val = (e.value.value as num).toDouble();
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(toY: val, color: colors[key] ?? Colors.grey, width: 24, borderRadius: BorderRadius.circular(6)),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final keys = data.keys.toList();
                  if (value.toInt() < keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(labels[keys[value.toInt()]] ?? '', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10)),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildGovernorateChart(Map<String, dynamic> data) {
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text(AppStrings.noData)));

    final entries = data.entries.toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: BarChart(
        BarChartData(
          barGroups: entries.asMap().entries.map((e) {
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(toY: (e.value.value as num).toDouble(), color: AppTheme.primaryColor, width: 16, borderRadius: BorderRadius.circular(4)),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < entries.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(entries[value.toInt()].key, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9)),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildSeverityChart(Map<String, dynamic> shortages) {
    final bySeverity = shortages['bySeverity'] as Map<String, dynamic>? ?? {};
    if (bySeverity.isEmpty) return const SizedBox(height: 200, child: Center(child: Text(AppStrings.noData)));

    final colors = {'critical': AppTheme.errorColor, 'high': Colors.deepOrange, 'medium': AppTheme.warningColor, 'low': AppTheme.successColor};
    final labels = {'critical': 'حرج', 'high': 'عالي', 'medium': 'متوسط', 'low': 'منخفض'};

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: PieChart(
        PieChartData(
          sections: bySeverity.entries.map((e) {
            return PieChartSectionData(
              value: (e.value as num).toDouble(),
              color: colors[e.key] ?? Colors.grey,
              title: '${labels[e.key] ?? e.key}\n${e.value}',
              titleStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
              radius: 70,
            );
          }).toList(),
          sectionsSpace: 3,
          centerSpaceRadius: 25,
        ),
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري تصدير البيانات...', style: TextStyle(fontFamily: 'Tajawal'))),
    );
  }
}
