import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:epi_core/epi_core.dart';
import '../providers/app_providers.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
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
              PopupMenuItem(value: '7d', child: Text('آخر 7 أيام', style: TextStyle(fontWeight: _selectedPeriod == '7d' ? FontWeight.bold : null))),
              PopupMenuItem(value: '30d', child: Text('آخر 30 يوم', style: TextStyle(fontWeight: _selectedPeriod == '30d' ? FontWeight.bold : null))),
              PopupMenuItem(value: '90d', child: Text('آخر 90 يوم', style: TextStyle(fontWeight: _selectedPeriod == '90d' ? FontWeight.bold : null))),
            ],
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.calendar_today),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPDF,
            tooltip: 'تقرير PDF',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCSV,
            tooltip: 'تصدير CSV',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportText,
            tooltip: 'مشاركة',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardAnalyticsProvider),
        child: analytics.when(
          loading: () => const EpiLoading.shimmer(),
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

    // Generate local insights
    final insights = LocalAnalyticsEngine.generateInsights(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health Score Card
          _buildHealthScore(data),
          const SizedBox(height: 20),

          // KPI Cards
          Row(
            children: [
              Expanded(child: _kpiCard('الإرساليات', '${submissions['total'] ?? 0}', 'اليوم: ${submissions['today'] ?? 0}', Icons.upload_file, AppTheme.primaryColor)),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('النواقص', '${shortages['total'] ?? 0}', 'محلول: ${shortages['resolved'] ?? 0}', Icons.warning, AppTheme.warningColor)),
            ],
          ),
          const SizedBox(height: 24),

          // Local AI Insights
          if (insights.isNotEmpty) ...[
            _sectionTitle('🤖 رؤى تحليلية'),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                ),
                child: Text(insight, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
              ),
            )),
            const SizedBox(height: 24),
          ],

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

  Widget _buildHealthScore(Map<String, dynamic> data) {
    final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
    final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
    final bySeverity = shortages['bySeverity'] as Map<String, dynamic>? ?? {};

    final score = LocalAnalyticsEngine.healthScore(
      totalShortages: shortages['total'] as int? ?? 0,
      resolvedShortages: shortages['resolved'] as int? ?? 0,
      criticalShortages: bySeverity['critical'] as int? ?? 0,
      totalSubmissions: submissions['total'] as int? ?? 0,
    );

    final color = score >= 80 ? AppTheme.successColor : score >= 50 ? AppTheme.warningColor : AppTheme.errorColor;
    final label = score >= 80 ? 'ممتاز' : score >= 50 ? 'متوسط' : 'ضعيف';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12)],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Center(
                  child: Text(
                    '$score',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مؤشر الأداء', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('الحالة: $label', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
          Text(subtitle, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600));
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

  void _exportCSV() {
    final analytics = ref.read(dashboardAnalyticsProvider);
    analytics.whenData((data) {
      final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
      final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
      final byStatus = submissions['byStatus'] as Map<String, dynamic>? ?? {};
      final bySeverity = shortages['bySeverity'] as Map<String, dynamic>? ?? {};

      final buffer = StringBuffer();
      buffer.writeln('Category,Key,Value');
      buffer.writeln('Submissions,Total,${submissions['total'] ?? 0}');
      buffer.writeln('Submissions,Today,${submissions['today'] ?? 0}');
      for (final entry in byStatus.entries) {
        buffer.writeln('Status,${entry.key},${entry.value}');
      }
      buffer.writeln('Shortages,Total,${shortages['total'] ?? 0}');
      buffer.writeln('Shortages,Resolved,${shortages['resolved'] ?? 0}');
      buffer.writeln('Shortages,Pending,${shortages['pending'] ?? 0}');
      for (final entry in bySeverity.entries) {
        buffer.writeln('Severity,${entry.key},${entry.value}');
      }

      Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (mounted) context.showSuccess('تم نسخ بيانات CSV إلى الحافظة');
    });
  }

  void _exportText() {
    final analytics = ref.read(dashboardAnalyticsProvider);
    analytics.whenData((data) {
      final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
      final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
      final byStatus = submissions['byStatus'] as Map<String, dynamic>? ?? {};
      final bySeverity = shortages['bySeverity'] as Map<String, dynamic>? ?? {};

      final buffer = StringBuffer();
      buffer.writeln('📊 تقرير تحليلات منصة مشرف EPI');
      buffer.writeln('═══════════════════════════════════');
      buffer.writeln('');
      buffer.writeln('📈 الإرساليات:');
      buffer.writeln('  • الإجمالي: ${submissions['total'] ?? 0}');
      buffer.writeln('  • اليوم: ${submissions['today'] ?? 0}');
      buffer.writeln('');
      buffer.writeln('📋 توزيع الحالات:');
      for (final entry in byStatus.entries) {
        final labels = {'draft': 'مسودة', 'submitted': 'مرسل', 'reviewed': 'مراجعة', 'approved': 'معتمد', 'rejected': 'مرفوض'};
        buffer.writeln('  • ${labels[entry.key] ?? entry.key}: ${entry.value}');
      }
      buffer.writeln('');
      buffer.writeln('⚠️ النواقص:');
      buffer.writeln('  • الإجمالي: ${shortages['total'] ?? 0}');
      buffer.writeln('  • المحلولة: ${shortages['resolved'] ?? 0}');
      buffer.writeln('  • المعلقة: ${shortages['pending'] ?? 0}');
      buffer.writeln('');
      buffer.writeln('📊 توزيع الخطورة:');
      for (final entry in bySeverity.entries) {
        final labels = {'critical': 'حرج', 'high': 'عالي', 'medium': 'متوسط', 'low': 'منخفض'};
        buffer.writeln('  • ${labels[entry.key] ?? entry.key}: ${entry.value}');
      }
      buffer.writeln('');
      buffer.writeln('═══════════════════════════════════');
      buffer.writeln('تاريخ التصدير: ${DateTime.now().toString().split('.')[0]}');

      Share.share(buffer.toString(), subject: 'تقرير تحليلات EPI Supervisor');
    });
  }

  Future<void> _exportPDF() async {
    final analytics = ref.read(dashboardAnalyticsProvider);
    analytics.whenData((data) async {
      final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
      final byStatus = submissions['byStatus'] as Map<String, dynamic>? ?? {};

      final periodLabel = _selectedPeriod == '7d'
          ? 'آخر 7 أيام'
          : _selectedPeriod == '30d'
              ? 'آخر 30 يوم'
              : 'آخر 90 يوم';

      try {
        if (mounted) context.showInfo('جارٍ إنشاء التقرير...');

        final file = await ReportGenerator.generatePDFReport(
          title: 'تقرير تحليلات منصة مشرف EPI',
          period: periodLabel,
          submissions: [], // Summary-only report for now
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

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'تقرير تحليلات EPI - $periodLabel',
        );
      } catch (e) {
        if (mounted) context.showError('فشل إنشاء التقرير: $e');
      }
    });
  }
}
