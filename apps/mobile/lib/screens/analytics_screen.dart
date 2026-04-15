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

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  String _selectedPeriod = '30d';
  String? _selectedFormId;
  String? _selectedGovernorateId;
  String? _selectedDistrictId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Build the current filter from UI state
  AnalyticsFilter get _currentFilter => AnalyticsFilter(
    governorateId: _selectedGovernorateId,
    districtId: _selectedDistrictId,
    formId: _selectedFormId,
    startDate: _startDate,
  );

  /// Normalize a DateTime to midnight (start of day) for consistent equality checks
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? get _startDate {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case '7d':
        return _dateOnly(now.subtract(const Duration(days: 7)));
      case '30d':
        return _dateOnly(now.subtract(const Duration(days: 30)));
      case '90d':
        return _dateOnly(now.subtract(const Duration(days: 90)));
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(dashboardAnalyticsProvider(_currentFilter));

    return Scaffold(
      appBar: EpiAppBar(
        title: AppStrings.analytics,
        showBackButton: false,
        actions: [
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'نظرة عامة', icon: Icon(Icons.dashboard, size: 18)),
            Tab(text: 'حسب النموذج', icon: Icon(Icons.description, size: 18)),
            Tab(text: 'فلاتر', icon: Icon(Icons.filter_list, size: 18)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(forceRefreshProvider)(_currentFilter.cacheKey);
          ref.invalidate(dashboardAnalyticsProvider(_currentFilter));
        },
        child: analytics.when(
          loading: () => const EpiLoading.shimmer(),
          error: (e, _) => EpiErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(dashboardAnalyticsProvider(_currentFilter)),
          ),
          data: (data) => TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(data),
              _buildFormAnalysisTab(data),
              _buildFilterTab(data),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 1: Overview (النظرة العامة)
  // ═══════════════════════════════════════════════════════════
  Widget _buildOverviewTab(Map<String, dynamic> data) {
    final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
    final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
    final byGovernorate = submissions['byGovernorate'] as Map<String, dynamic>? ?? {};
    final byStatus = submissions['byStatus'] as Map<String, dynamic>? ?? {};

    final insights = LocalAnalyticsEngine.generateInsights(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActiveFiltersBar(),
          _buildHealthScore(data),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _kpiCard('الإرساليات', '${submissions['total'] ?? 0}', 'اليوم: ${submissions['today'] ?? 0}', Icons.upload_file, AppTheme.primaryColor)),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('النواقص', '${shortages['total'] ?? 0}', 'محلول: ${shortages['resolved'] ?? 0}', Icons.warning, AppTheme.warningColor)),
            ],
          ),
          const SizedBox(height: 24),
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
          _sectionTitle('توزيع الحالات'),
          const SizedBox(height: 12),
          _buildStatusBarChart(byStatus),
          const SizedBox(height: 24),
          _sectionTitle('الإرساليات حسب المحافظة'),
          const SizedBox(height: 12),
          _buildGovernorateChart(byGovernorate),
          const SizedBox(height: 24),
          _sectionTitle('النواقص حسب الخطورة'),
          const SizedBox(height: 12),
          _buildSeverityChart(shortages),
        ],
      ),
    );
  }

  /// Shows which filters are currently active
  Widget _buildActiveFiltersBar() {
    final chips = <Widget>[];
    if (_selectedGovernorateId != null) {
      chips.add(_activeFilterChip('محافظة محددة', () => setState(() => _selectedGovernorateId = null)));
    }
    if (_selectedDistrictId != null) {
      chips.add(_activeFilterChip('مديرية محددة', () => setState(() => _selectedDistrictId = null)));
    }
    if (_selectedFormId != null) {
      chips.add(_activeFilterChip('نموذج محدد', () => setState(() => _selectedFormId = null)));
    }
    if (_selectedPeriod != '30d') {
      final labels = {'7d': '7 أيام', '90d': '90 يوم'};
      chips.add(_activeFilterChip(labels[_selectedPeriod] ?? _selectedPeriod, () => setState(() => _selectedPeriod = '30d')));
    }
    if (chips.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          const Text('فلاتر نشطة:', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
          ...chips,
        ],
      ),
    );
  }

  Widget _activeFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onRemove,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 2: Per-Form Analysis (تحليل حسب النموذج)
  // ═══════════════════════════════════════════════════════════
  Widget _buildFormAnalysisTab(Map<String, dynamic> data) {
    final forms = (data['forms'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (forms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد بيانات تحليلية للنماذج', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: forms.length + 1, // +1 for summary header
      itemBuilder: (context, index) {
        if (index == 0) return _buildFormsSummaryHeader(forms);
        return _buildFormCard(forms[index - 1]);
      },
    );
  }

  /// Summary header showing total submissions across all forms
  Widget _buildFormsSummaryHeader(List<Map<String, dynamic>> forms) {
    int totalAll = 0;
    int totalQuestions = 0;
    for (final f in forms) {
      final stats = f['stats'] as Map<String, dynamic>? ?? {};
      totalAll += (stats['total'] as int?) ?? 0;
      final qs = (f['questions'] as List?) ?? [];
      totalQuestions += qs.length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
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
                Text('${forms.length} نماذج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('إجمالي الإرساليات: $totalAll | $totalQuestions سؤال', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.analytics, color: Colors.white, size: 32),
        ],
      ),
    );
  }

  Widget _buildFormCard(Map<String, dynamic> form) {
    final titleAr = form['titleAr'] as String? ?? 'نموذج';
    final stats = form['stats'] as Map<String, dynamic>? ?? {};
    final total = stats['total'] as int? ?? 0;
    final byStatus = stats['byStatus'] as Map<String, dynamic>? ?? {};
    final questions = (form['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final statusColors = {
      'draft': Colors.grey,
      'submitted': AppTheme.infoColor,
      'reviewed': AppTheme.warningColor,
      'approved': AppTheme.successColor,
      'rejected': AppTheme.errorColor,
    };
    final statusLabels = {
      'draft': 'مسودة',
      'submitted': 'مرسل',
      'reviewed': 'مراجعة',
      'approved': 'معتمد',
      'rejected': 'مرفوض',
    };

    // Calculate overall completion rate for this form
    int avgCompletion = 0;
    if (questions.isNotEmpty) {
      int sum = 0;
      for (final q in questions) {
        sum += (q['completionRate'] as int?) ?? 0;
      }
      avgCompletion = (sum / questions.length).round();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description, color: AppTheme.primaryColor, size: 22),
          ),
          title: Text(
            titleAr,
            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Row(
            children: [
              Text(
                'إجمالي: $total',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary),
              ),
              if (questions.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (avgCompletion >= 80 ? AppTheme.successColor : avgCompletion >= 50 ? AppTheme.warningColor : AppTheme.errorColor).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'اكتمال: $avgCompletion%',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: avgCompletion >= 80 ? AppTheme.successColor : avgCompletion >= 50 ? AppTheme.warningColor : AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          children: [
            // Status breakdown
            if (byStatus.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerRight,
                child: Text('توزيع الحالات:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: byStatus.entries.map((e) {
                  final color = statusColors[e.key] ?? Colors.grey;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${statusLabels[e.key] ?? e.key}: ${e.value}',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: color, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Question analysis
            if (questions.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تحليل الأسئلة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${questions.length} أسئلة', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint)),
                ],
              ),
              const SizedBox(height: 8),
              ...questions.asMap().entries.map((entry) {
                return _buildQuestionAnalysis(entry.value, index: entry.key + 1);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionAnalysis(Map<String, dynamic> question, {int? index}) {
    final label = question['label'] as String? ?? '';
    final type = question['type'] as String? ?? 'text';
    final completionRate = question['completionRate'] as int? ?? 0;
    final answered = question['answered'] as int? ?? 0;
    final notAnswered = question['notAnswered'] as int? ?? 0;
    final totalSubmissions = question['totalSubmissions'] as int? ?? 0;
    final distribution = question['distribution'] as Map<String, dynamic>? ?? {};
    final yesCount = question['yesCount'] as int?;
    final noCount = question['noCount'] as int?;
    final yesRate = question['yesRate'] as int?;
    final numericStats = question['numericStats'] as Map<String, dynamic>?;

    final rateColor = completionRate >= 80
        ? AppTheme.successColor
        : completionRate >= 50
            ? AppTheme.warningColor
            : AppTheme.errorColor;

    // Type icon
    IconData typeIcon;
    switch (type) {
      case 'yesno':
        typeIcon = Icons.check_circle_outline;
        break;
      case 'number':
        typeIcon = Icons.numbers;
        break;
      case 'select':
      case 'radio':
        typeIcon = Icons.radio_button_checked;
        break;
      case 'multiselect':
        typeIcon = Icons.checklist;
        break;
      case 'date':
        typeIcon = Icons.calendar_today;
        break;
      case 'text':
        typeIcon = Icons.text_fields;
        break;
      default:
        typeIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header with number, icon, label, and completion badge
          Row(
            children: [
              if (index != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('$index', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(typeIcon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              // Completion badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      completionRate >= 80 ? Icons.check_circle : completionRate >= 50 ? Icons.warning : Icons.error,
                      size: 12,
                      color: rateColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$completionRate%',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: rateColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'تم الإجابة: $answered / $totalSubmissions${notAnswered > 0 ? ' ($notAnswered بدون إجابة)' : ''}',
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint),
          ),
          const SizedBox(height: 8),

          // Completion bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalSubmissions > 0 ? answered / totalSubmissions : 0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(rateColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),

          // Type-specific analysis
          if (type == 'yesno' && yesCount != null) ...[
            Row(
              children: [
                Expanded(
                  child: _miniStatCard('نعم', '$yesCount', '$yesRate%', AppTheme.successColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniStatCard('لا', '${noCount ?? (answered - yesCount)}', '${100 - (yesRate ?? 0)}%', AppTheme.errorColor),
                ),
              ],
            ),
          ] else if (type == 'number' && numericStats != null) ...[
            Row(
              children: [
                Expanded(child: _miniStatCard('الحد الأدنى', '${numericStats['min'] ?? '-'}', '', AppTheme.infoColor)),
                const SizedBox(width: 8),
                Expanded(child: _miniStatCard('المتوسط', '${numericStats['avg'] ?? '-'}', '', AppTheme.primaryColor)),
                const SizedBox(width: 8),
                Expanded(child: _miniStatCard('الحد الأقصى', '${numericStats['max'] ?? '-'}', '', AppTheme.warningColor)),
              ],
            ),
            if (numericStats['total'] != null) ...[
              const SizedBox(height: 6),
              Text('المجموع الكلي: ${numericStats['total']}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint)),
            ],
          ] else if (distribution.isNotEmpty && distribution.length <= 15) ...[
            // Distribution bars for select/radio/multiselect fields
            ...distribution.entries.take(10).map((e) {
              final pct = answered > 0 ? ((e.value / answered) * 100).toStringAsFixed(0) : '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(e.key, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: answered > 0 ? e.value / answered : 0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text('${e.value} ($pct%)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10), textAlign: TextAlign.end),
                    ),
                  ],
                ),
              );
            }),
            if (distribution.length > 10)
              Text('+ ${distribution.length - 10} خيارات أخرى', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.textHint)),
          ] else if (distribution.isNotEmpty && distribution.length > 15) ...[
            // Too many values — show top 5
            Text('أكثر الإجابات تكراراً:', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            ...(() {
              final sorted = distribution.entries.toList()
                ..sort((a, b) => (b.value as int).compareTo(a.value as int));
              return sorted.take(5).map((e) {
                final pct = answered > 0 ? ((e.value / answered) * 100).toStringAsFixed(0) : '0';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.key, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11), overflow: TextOverflow.ellipsis)),
                      Text('${e.value} ($pct%)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              });
            }()),
          ],
        ],
      ),
    );
  }

  Widget _miniStatCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 16, color: color)),
          Text(title, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: color)),
          if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 3: Filters (فلاتر)
  // ═══════════════════════════════════════════════════════════
  Widget _buildFilterTab(Map<String, dynamic> data) {
    final forms = (data['forms'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final govBreakdown = (data['governorateBreakdown'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final governorates = ref.watch(governoratesProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ Form filter ═══
          _sectionTitle('فلتر حسب النموذج'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _selectedFormId,
                hint: const Text('جميع النماذج', style: TextStyle(fontFamily: 'Tajawal')),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('جميع النماذج', style: TextStyle(fontFamily: 'Tajawal')),
                  ),
                  ...forms.map((f) => DropdownMenuItem<String?>(
                    value: f['formId'] as String?,
                    child: Text(f['titleAr'] as String? ?? '', style: const TextStyle(fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => setState(() => _selectedFormId = v),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ═══ Governorate filter ═══
          _sectionTitle('فلتر حسب المحافظة'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _selectedGovernorateId,
                hint: const Text('جميع المحافظات', style: TextStyle(fontFamily: 'Tajawal')),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('جميع المحافظات', style: TextStyle(fontFamily: 'Tajawal')),
                  ),
                  ...governorates.map((gov) => DropdownMenuItem<String?>(
                    value: gov['id'] as String?,
                    child: Text(gov['name_ar'] as String? ?? '', style: const TextStyle(fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => setState(() {
                  _selectedGovernorateId = v;
                  _selectedDistrictId = null; // Reset district when governorate changes
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // District filter (only when governorate is selected)
          if (_selectedGovernorateId != null) ...[
            _buildDistrictDropdown(),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 12),

          // ═══ Period filter ═══
          _sectionTitle('الفترة الزمنية'),
          const SizedBox(height: 12),
          Row(
            children: [
              _periodChip('7 أيام', '7d'),
              const SizedBox(width: 8),
              _periodChip('30 يوم', '30d'),
              const SizedBox(width: 8),
              _periodChip('90 يوم', '90d'),
            ],
          ),
          const SizedBox(height: 16),

          // ═══ Apply / Reset buttons ═══
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Filters are already applied reactively via _currentFilter
                    _tabController.animateTo(0); // Go to overview to see results
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('تطبيق الفلاتر', style: TextStyle(fontFamily: 'Tajawal')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _selectedFormId = null;
                  _selectedGovernorateId = null;
                  _selectedDistrictId = null;
                  _selectedPeriod = '30d';
                }),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة تعيين', style: TextStyle(fontFamily: 'Tajawal')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ═══ Governorate breakdown ═══
          if (govBreakdown.isNotEmpty) ...[
            _sectionTitle('الإرساليات حسب المحافظة'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
              ),
              child: Column(
                children: govBreakdown.take(15).map((gov) {
                  final name = gov['nameAr'] as String? ?? '';
                  final count = gov['count'] as int? ?? 0;
                  final maxCount = govBreakdown.first['count'] as int? ?? 1;
                  final pct = count / maxCount;
                  final isSelected = _selectedGovernorateId == gov['id'];

                  return InkWell(
                    onTap: () => setState(() {
                      _selectedGovernorateId = isSelected ? null : gov['id'] as String?;
                      _selectedDistrictId = null;
                    }),
                    child: Container(
                      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Text('$count', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14)),
                              if (isSelected) const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.check_circle, size: 16, color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.6)),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ═══ Selected form detail ═══
          if (_selectedFormId != null) ...[
            _buildSelectedFormDetail(data),
          ],
        ],
      ),
    );
  }

  Widget _buildDistrictDropdown() {
    final districts = ref.watch(districtsProvider(_selectedGovernorateId)).valueOrNull ?? [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: _selectedDistrictId,
          hint: const Text('جميع المديريات', style: TextStyle(fontFamily: 'Tajawal')),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('جميع المديريات', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ...districts.map((d) => DropdownMenuItem<String?>(
              value: d['id'] as String?,
              child: Text(d['name_ar'] as String? ?? '', style: const TextStyle(fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (v) => setState(() => _selectedDistrictId = v),
        ),
      ),
    );
  }

  Widget _periodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFormDetail(Map<String, dynamic> data) {
    final forms = (data['forms'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final selectedForm = forms.firstWhere(
      (f) => f['formId'] == _selectedFormId,
      orElse: () => {},
    );

    if (selectedForm.isEmpty) return const SizedBox();

    final questions = (selectedForm['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final titleAr = selectedForm['titleAr'] as String? ?? '';
    final stats = selectedForm['stats'] as Map<String, dynamic>? ?? {};
    final total = stats['total'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('تحليل أسئلة: $titleAr'),
        const SizedBox(height: 4),
        Text('إجمالي الإرساليات: $total', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textHint)),
        const SizedBox(height: 12),
        if (questions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('لا توجد بيانات تحليلية لهذا النموذج', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
            ),
          )
        else
          ...questions.asMap().entries.map((entry) => _buildQuestionAnalysis(entry.value, index: entry.key + 1)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Shared widgets
  // ═══════════════════════════════════════════════════════════

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

    // ═══ FIX: Sort by value descending and take top 8 to prevent overflow on mobile ═══
    final sorted = data.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final entries = sorted.take(8).toList();

    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: entries.isNotEmpty ? (entries.first.value as num).toDouble() * 1.2 : 10,
          barGroups: entries.asMap().entries.map((e) {
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                toY: (e.value.value as num).toDouble(),
                color: AppTheme.primaryColor,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < entries.length) {
                    // ═══ FIX: Use abbreviated names and avoid RotatedBox to prevent overflow ═══
                    final name = entries[value.toInt()].key;
                    final shortName = name.length > 6 ? '${name.substring(0, 5)}…' : name;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        shortName,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9),
                        textAlign: TextAlign.center,
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
    final analytics = ref.read(dashboardAnalyticsProvider(_currentFilter));
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
    final analytics = ref.read(dashboardAnalyticsProvider(_currentFilter));
    analytics.whenData((data) {
      final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
      final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
      final byStatus = submissions['byStatus'] as Map<String, dynamic>? ?? {};
      final bySeverity = shortages['bySeverity'] as Map<String, dynamic>? ?? {};

      final buffer = StringBuffer();
      buffer.writeln("📊 تقرير تحليلات EPI Supervisors");
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

      final forms = (data['forms'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (forms.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('📝 ملخص النماذج:');
        for (final form in forms) {
          final title = form['titleAr'] as String? ?? '';
          final stats = form['stats'] as Map<String, dynamic>? ?? {};
          buffer.writeln('  • $title: ${stats['total'] ?? 0} إرسالية');
        }
      }

      buffer.writeln('');
      buffer.writeln('═══════════════════════════════════');
      buffer.writeln('تاريخ التصدير: ${DateTime.now().toString().split('.')[0]}');

      SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'تقرير تحليلات EPI Supervisor'));
    });
  }

  Future<void> _exportPDF() async {
    final analytics = ref.read(dashboardAnalyticsProvider(_currentFilter));
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
          title: "تقرير تحليلات EPI Supervisors",
          period: periodLabel,
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
          subject: 'تقرير تحليلات EPI - $periodLabel',
        ));
      } catch (e) {
        if (mounted) context.showError('فشل إنشاء التقرير: $e');
      }
    });
  }
}
