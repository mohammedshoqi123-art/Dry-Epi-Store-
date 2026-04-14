import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnim;
  late AnimationController _cardsAnim;
  late AnimationController _pulseAnim;
  int _selectedQuickAction = -1;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _cardsAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _headerAnim.forward();
    Future.delayed(const Duration(milliseconds: 200), () => _cardsAnim.forward());
    _pulseAnim.repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider.future).then((service) {
        if (service.currentState.pendingCount > 0) {
          service.sync().catchError((_) => SyncCycleResult.empty());
        }
      }).catchError((_) => null);
    });
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _cardsAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(dashboardAnalyticsProvider(const AnalyticsFilter()));
    final authState = ref.watch(authStateProvider);
    final pendingAsync = ref.watch(syncPendingCountProvider);
    final pendingCount = pendingAsync.valueOrNull ?? 0;

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          ref.invalidate(dashboardAnalyticsProvider(const AnalyticsFilter()));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ═══ Animated Header ═══
            SliverToBoxAdapter(
              child: _buildHeroHeader(authState.valueOrNull?.fullName ?? 'مستخدم'),
            ),

            // ═══ Pending Sync ═══
            if (pendingCount > 0)
              SliverToBoxAdapter(child: _buildSyncBanner(pendingCount)),

            // ═══ Content ═══
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: analytics.when(
                loading: () => SliverList(delegate: SliverChildListDelegate([
                  const SizedBox(height: 200),
                  const Center(child: EpiLoading.shimmer()),
                ])),
                error: (e, _) => SliverList(delegate: SliverChildListDelegate([
                  const SizedBox(height: 100),
                  EpiErrorWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(dashboardAnalyticsProvider(const AnalyticsFilter())),
                  ),
                ])),
                data: (data) => _buildDashboardContent(data),
              ),
            ),

            // Bottom padding for bottom nav
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HERO HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeroHeader(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'صباح الخير' : hour < 17 ? 'مساء الخير' : 'تصبح على خير';
    final emoji = hour < 12 ? '☀️' : hour < 17 ? '🌤️' : '🌙';

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: _headerAnim,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00897B), Color(0xFF004D40)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00897B).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting $emoji',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification bell with pulse
                  GestureDetector(
                    onTap: () => context.go('/notifications'),
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, _) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15 + 0.05 * _pulseAnim.value),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Date row
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.white60, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _getDateString(),
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    const days = ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    return '${days[now.weekday - 1]}، ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _buildSyncBanner(int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: Colors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text('$count استمارة بانتظار المزامنة',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(syncServiceProvider.future).then((s) => s.sync().catchError((_) => SyncCycleResult.empty()));
            },
            child: Text('مزامنة', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DASHBOARD CONTENT
  // ═══════════════════════════════════════════════════════════
  SliverList _buildDashboardContent(Map<String, dynamic> data) {
    final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
    final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
    final total = submissions['total'] as int? ?? 0;
    final today = submissions['today'] as int? ?? 0;
    final totalShortages = shortages['total'] as int? ?? 0;
    final resolved = shortages['resolved'] as int? ?? 0;
    final bySeverity = shortages['bySeverity'] as Map<String, dynamic>? ?? {};
    final critical = bySeverity['critical'] as int? ?? 0;
    final completionRate = totalShortages > 0 ? ((resolved / totalShortages) * 100).round() : 0;

    return SliverList(
      delegate: SliverChildListDelegate([
        // ═══ KPI Cards — animated grid ═══
        _buildKPIGrid(total, today, totalShortages, resolved, critical, completionRate),
        const SizedBox(height: 20),

        // ═══ Health Ring ═══
        _buildHealthRing(data),
        const SizedBox(height: 20),

        // ═══ Quick Actions — horizontal scroll ═══
        _sectionTitle('إجراءات سريعة'),
        const SizedBox(height: 12),
        _buildQuickActions(),
        const SizedBox(height: 20),

        // ═══ Status Distribution ═══
        _sectionTitle('توزيع الحالات'),
        const SizedBox(height: 12),
        _buildStatusDonut(submissions['byStatus'] as Map<String, dynamic>? ?? {}),
        const SizedBox(height: 20),

        // ═══ Weekly Trend ═══
        _sectionTitle('النشاط الأسبوعي'),
        const SizedBox(height: 12),
        _buildTrendLine(submissions['byDay'] as Map<String, dynamic>? ?? {}),
        const SizedBox(height: 20),

        // ═══ Recent Activity ═══
        _sectionTitle('آخر النشاطات'),
        const SizedBox(height: 12),
        _buildActivityFeed(data),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // KPI GRID
  // ═══════════════════════════════════════════════════════════
  Widget _buildKPIGrid(int total, int today, int shortages, int resolved, int critical, int rate) {
    final items = [
      _KPI('الإرساليات', total, today, Icons.upload_file_rounded, AppTheme.primaryColor, 'اليوم'),
      _KPI('النواقص', shortages, resolved, Icons.warning_amber_rounded, AppTheme.warningColor, 'محلول'),
      _KPI('حرج', critical, 0, Icons.local_fire_department_rounded, AppTheme.errorColor, critical > 0 ? 'يحتاج تدخل!' : 'لا يوجد'),
      _KPI('الإنجاز', rate, 0, Icons.speed_rounded, AppTheme.successColor, '%'),
    ];

    return AnimatedBuilder(
      animation: _cardsAnim,
      builder: (context, _) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final delay = i * 0.15;
            final animValue = Curves.easeOutCubic.transform(
              (_cardsAnim.value - delay).clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: animValue,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - animValue)),
                child: _buildKPICard(items[i]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKPICard(_KPI kpi) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (kpi.label == 'الإرساليات') context.go('/submissions');
        if (kpi.label == 'النواقص' || kpi.label == 'حرج') context.go('/analytics');
        if (kpi.label == 'الإنجاز') context.go('/analytics');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: kpi.color.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kpi.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(kpi.icon, color: kpi.color, size: 20),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade300),
              ],
            ),
            const Spacer(),
            _AnimatedCounter(
              value: kpi.mainValue,
              color: kpi.color,
              fontSize: 28,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(kpi.label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
                if (kpi.label != 'الإنجاز')
                  Text('${kpi.subValue} ${kpi.subLabel}',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: kpi.color.withValues(alpha: 0.7))),
                if (kpi.label == 'الإنجاز')
                  Text(kpi.subLabel,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: kpi.color.withValues(alpha: 0.7))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEALTH RING
  // ═══════════════════════════════════════════════════════════
  Widget _buildHealthRing(Map<String, dynamic> data) {
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
    final label = score >= 80 ? 'أداء ممتاز' : score >= 50 ? 'أداء متوسط' : 'يحتاج تحسين';
    final insights = LocalAnalyticsEngine.generateInsights(data);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          // Animated ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 7,
                      backgroundColor: Colors.grey.shade100,
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
              );
            },
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 6),
                if (insights.isNotEmpty)
                  Text(
                    insights.first,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 10),
                // Mini insight pills
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: insights.skip(1).take(2).map((insight) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        insight.length > 35 ? '${insight.substring(0, 32)}...' : insight,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.primaryColor),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // QUICK ACTIONS — Horizontal Scroll
  // ═══════════════════════════════════════════════════════════
  Widget _buildQuickActions() {
    final actions = [
      _QA(Icons.add_circle_outline_rounded, 'إرسال جديد', '/forms', const Color(0xFF00897B)),
      _QA(Icons.description_rounded, 'النماذج', '/forms', const Color(0xFF5C6BC0)),
      _QA(Icons.map_outlined, 'الخريطة', '/map', const Color(0xFF1E88E5)),
      _QA(Icons.bar_chart_rounded, 'التحليلات', '/analytics', const Color(0xFF43A047)),
      _QA(Icons.smart_toy_outlined, 'المساعد الذكي', '/ai', const Color(0xFFFF8F00)),
      _QA(Icons.admin_panel_settings_rounded, 'الإدارة', '/admin', const Color(0xFFE53935)),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = actions[i];
          final isSelected = _selectedQuickAction == i;
          return GestureDetector(
            onTapDown: (_) => setState(() => _selectedQuickAction = i),
            onTapUp: (_) {
              HapticFeedback.lightImpact();
              context.go(a.route);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => _selectedQuickAction = -1);
              });
            },
            onTapCancel: () => setState(() => _selectedQuickAction = -1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 82,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? a.color.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? a.color.withValues(alpha: 0.4) : Colors.grey.shade100,
                  width: 1.5,
                ),
                boxShadow: [BoxShadow(color: a.color.withValues(alpha: isSelected ? 0.12 : 0.04), blurRadius: 12, offset: const Offset(0, 3))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: isSelected ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(a.icon, color: a.color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(a.label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: a.color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATUS DONUT — interactive tap
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatusDonut(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyCard('لا توجد بيانات');

    final colors = {
      'draft': Colors.grey.shade400,
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

    final total = data.values.fold<int>(0, (s, v) => s + (v as int));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)]),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 30,
                sections: data.entries.map((e) {
                  final pct = total > 0 ? (e.value as int) / total * 100 : 0;
                  return PieChartSectionData(
                    value: (e.value as num).toDouble(),
                    color: colors[e.key] ?? Colors.grey,
                    radius: 45,
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: data.entries.map((e) {
                final pct = total > 0 ? ((e.value as int) / total * 100).toStringAsFixed(0) : '0';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key], borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(labels[e.key] ?? e.key, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                      Text('${e.value}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Text('($pct%)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.textHint)),
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

  // ═══════════════════════════════════════════════════════════
  // TREND LINE
  // ═══════════════════════════════════════════════════════════
  Widget _buildTrendLine(Map<String, dynamic> dayData) {
    if (dayData.isEmpty) return _emptyCard('لا توجد بيانات');

    final entries = dayData.entries.toList();
    final maxY = entries.fold<num>(1, (m, e) => e.value > m ? e.value : m).toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)]),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppTheme.textHint)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i >= 0 && i < entries.length && (i % 2 == 0 || entries.length <= 7)) {
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(entries[i].key, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppTheme.textHint)));
              }
              return const SizedBox();
            })),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value.value as num).toDouble())).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppTheme.primaryColor,
              barWidth: 2.5,
              dotData: FlDotData(show: true, getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 3, color: AppTheme.primaryColor, strokeWidth: 0)),
              belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AppTheme.primaryColor.withValues(alpha: 0.15), AppTheme.primaryColor.withValues(alpha: 0.02)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${entries[s.x.toInt()].key}\n${s.y.toInt()} إرسالية', const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white))).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIVITY FEED
  // ═══════════════════════════════════════════════════════════
  Widget _buildActivityFeed(Map<String, dynamic> data) {
    final insights = LocalAnalyticsEngine.generateInsights(data);
    if (insights.isEmpty) return _emptyCard('لا توجد نشاطات حديثة');

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)]),
      child: Column(
        children: insights.asMap().entries.map((entry) {
          final isFirst = entry.key == 0;
          final isLast = entry.key == insights.length - 1;
          return InkWell(
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(20) : Radius.zero,
              bottom: isLast ? const Radius.circular(20) : Radius.zero,
            ),
            onTap: () => context.go('/analytics'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(entry.value.substring(0, 1), style: const TextStyle(fontSize: 16))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: AppTheme.textHint, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      height: 120,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.inbox_rounded, size: 32, color: Colors.grey.shade300), const SizedBox(height: 8), Text(msg, style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade400, fontSize: 13))],
      )),
    );
  }
}

// ═══ Helper classes ═══
class _KPI {
  final String label;
  final int mainValue;
  final int subValue;
  final IconData icon;
  final Color color;
  final String subLabel;
  _KPI(this.label, this.mainValue, this.subValue, this.icon, this.color, this.subLabel);
}

class _QA {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  _QA(this.icon, this.label, this.route, this.color);
}

/// Animated counter that counts up to [value] over 800ms
class _AnimatedCounter extends StatefulWidget {
  final int value;
  final Color color;
  final double fontSize;
  const _AnimatedCounter({required this.value, required this.color, this.fontSize = 28});

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _lastValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween(begin: 0.0, end: widget.value.toDouble()).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _lastValue = widget.value;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween(begin: _lastValue.toDouble(), end: widget.value.toDouble()).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _lastValue = widget.value;
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Text(
          _anim.value.round().toString(),
          style: TextStyle(fontFamily: 'Cairo', fontSize: widget.fontSize, fontWeight: FontWeight.w700, color: widget.color),
        );
      },
    );
  }
}
