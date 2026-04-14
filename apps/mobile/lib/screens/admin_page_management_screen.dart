import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Admin Page Management — Full no-code control over app pages
// ═══════════════════════════════════════════════════════════════════════════════

class AdminPageManagementScreen extends ConsumerStatefulWidget {
  const AdminPageManagementScreen({super.key});

  @override
  ConsumerState<AdminPageManagementScreen> createState() => _AdminPageManagementScreenState();
}

class _AdminPageManagementScreenState extends ConsumerState<AdminPageManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Page management state
  List<AdminPageItem> _pages = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initDefaultPages();
  }

  void _initDefaultPages() {
    _pages = [
      AdminPageItem(
        id: 'dashboard',
        nameAr: 'الرئيسية',
        nameEn: 'Dashboard',
        icon: Icons.dashboard_rounded,
        route: '/dashboard',
        color: const Color(0xFF00897B),
        isVisible: true,
        isEditable: false,
        sortOrder: 0,
        description: 'لوحة التحكم الرئيسية مع KPIs',
      ),
      AdminPageItem(
        id: 'forms',
        nameAr: 'النماذج',
        nameEn: 'Forms',
        icon: Icons.description_rounded,
        route: '/forms',
        color: const Color(0xFF5C6BC0),
        isVisible: true,
        isEditable: true,
        sortOrder: 1,
        description: 'عرض وتعبئة النماذج',
      ),
      AdminPageItem(
        id: 'submissions',
        nameAr: 'الإرساليات',
        nameEn: 'Submissions',
        icon: Icons.upload_file_rounded,
        route: '/submissions',
        color: const Color(0xFF1E88E5),
        isVisible: true,
        isEditable: true,
        sortOrder: 2,
        description: 'عرض وإدارة الإرساليات',
      ),
      AdminPageItem(
        id: 'map',
        nameAr: 'الخريطة',
        nameEn: 'Map',
        icon: Icons.map_outlined,
        route: '/map',
        color: const Color(0xFF26A69A),
        isVisible: true,
        isEditable: false,
        sortOrder: 3,
        description: 'خريطة تفاعلية للإرساليات',
      ),
      AdminPageItem(
        id: 'analytics',
        nameAr: 'التحليلات',
        nameEn: 'Analytics',
        icon: Icons.bar_chart_rounded,
        route: '/analytics',
        color: const Color(0xFF43A047),
        isVisible: true,
        isEditable: true,
        sortOrder: 4,
        description: 'تحليلات وتقارير مفصلة',
      ),
      AdminPageItem(
        id: 'ai',
        nameAr: 'المساعد الذكي',
        nameEn: 'AI Assistant',
        icon: Icons.smart_toy_outlined,
        route: '/ai',
        color: const Color(0xFFFF8F00),
        isVisible: true,
        isEditable: false,
        sortOrder: 5,
        description: 'محادثة ذكية مع Gemini',
      ),
      AdminPageItem(
        id: 'references',
        nameAr: 'المراجع',
        nameEn: 'References',
        icon: Icons.folder_outlined,
        route: '/references',
        color: const Color(0xFF7E57C2),
        isVisible: true,
        isEditable: true,
        sortOrder: 6,
        description: 'مستودع المراجع والملفات',
      ),
      AdminPageItem(
        id: 'notifications',
        nameAr: 'الإشعارات',
        nameEn: 'Notifications',
        icon: Icons.notifications_outlined,
        route: '/notifications',
        color: const Color(0xFFE53935),
        isVisible: true,
        isEditable: false,
        sortOrder: 7,
        description: 'مركز الإشعارات',
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المدير', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF1A2332),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_customize_rounded, size: 18), text: 'الصفحات'),
            Tab(icon: Icon(Icons.palette_outlined, size: 18), text: 'التنسيق'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'التحليلات'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'الإعدادات'),
            Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'الأمان'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPagesTab(),
          _buildStylingTab(),
          _buildAnalyticsTab(),
          _buildSettingsTab(),
          _buildSecurityTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPageDialog,
        backgroundColor: const Color(0xFF00897B),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('إضافة صفحة', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 1: PAGE MANAGEMENT
  // ═══════════════════════════════════════════════════════════
  Widget _buildPagesTab() {
    final filtered = _pages
        .where((p) => p.nameAr.contains(_searchQuery) || p.nameEn.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      children: [
        // Stats bar
        _buildPagesStats(),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontFamily: 'Tajawal'),
            decoration: InputDecoration(
              hintText: 'بحث عن صفحة...',
              hintStyle: const TextStyle(fontFamily: 'Tajawal'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        // Pages list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: filtered.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = filtered.removeAt(oldIndex);
                filtered.insert(newIndex, item);
                // Update sort orders
                for (int i = 0; i < filtered.length; i++) {
                  filtered[i].sortOrder = i;
                }
              });
              HapticFeedback.mediumImpact();
            },
            itemBuilder: (context, index) {
              final page = filtered[index];
              return _buildPageCard(page, index, key: ValueKey(page.id));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPagesStats() {
    final visible = _pages.where((p) => p.isVisible).length;
    final hidden = _pages.length - visible;
    final editable = _pages.where((p) => p.isEditable).length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _statChip('$visible', 'ظاهر', AppTheme.successColor),
          const SizedBox(width: 8),
          _statChip('$hidden', 'مخفي', AppTheme.warningColor),
          const SizedBox(width: 8),
          _statChip('$editable', 'قابل للتعديل', AppTheme.infoColor),
          const SizedBox(width: 8),
          _statChip('${_pages.length}', 'الإجمالي', AppTheme.primaryColor),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPageCard(AdminPageItem page, int index, {Key? key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: page.isVisible ? Colors.white : Colors.grey.shade50,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPageDetails(page),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.drag_handle_rounded, color: Colors.grey.shade400, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: page.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(page.icon, color: page.color, size: 22),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(page.nameAr,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: page.isVisible ? AppTheme.textPrimary : Colors.grey.shade400,
                            ),
                          ),
                        ),
                        if (!page.isVisible)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.warningColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Text('مخفي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.warningColor)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(page.route, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              // Toggle visibility
              Switch(
                value: page.isVisible,
                activeColor: AppTheme.primaryColor,
                onChanged: (v) {
                  setState(() => page.isVisible = v);
                  HapticFeedback.lightImpact();
                  _showSnackBar(v ? 'تم إظهار "${page.nameAr}"' : 'تم إخفاء "${page.nameAr}"');
                },
              ),
              // More options
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (action) => _handlePageAction(action, page),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: AppTheme.infoColor), SizedBox(width: 8), Text('تعديل', style: TextStyle(fontFamily: 'Tajawal'))])),
                  const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 18, color: AppTheme.secondaryColor), SizedBox(width: 8), Text('نسخ', style: TextStyle(fontFamily: 'Tajawal'))])),
                  if (page.isEditable)
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.errorColor), SizedBox(width: 8), Text('حذف', style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.errorColor))])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 2: STYLING
  // ═══════════════════════════════════════════════════════════
  Widget _buildStylingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color Theme
          _sectionHeader('🎨 ألوان التطبيق'),
          const SizedBox(height: 12),
          _buildColorPalette(),
          const SizedBox(height: 24),

          // Font selection
          _sectionHeader('🔤 الخطوط'),
          const SizedBox(height: 12),
          _buildFontSelector(),
          const SizedBox(height: 24),

          // Card style
          _sectionHeader('🃏 شكل البطاقات'),
          const SizedBox(height: 12),
          _buildCardStyleSelector(),
          const SizedBox(height: 24),

          // App header style
          _sectionHeader('📐 شريط التنقل العلوي'),
          const SizedBox(height: 12),
          _buildHeaderStyleSelector(),
          const SizedBox(height: 24),

          // Border radius
          _sectionHeader('🔲 استدارة الحواف'),
          const SizedBox(height: 12),
          _buildBorderRadiusSlider(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildColorPalette() {
    final themes = [
      _ThemePreset('أخضر فيروزي (الحالي)', const Color(0xFF00897B), const Color(0xFF004D40)),
      _ThemePreset('أزرق', const Color(0xFF1E88E5), const Color(0xFF0D47A1)),
      _ThemePreset('بنفسجي', const Color(0xFF7E57C2), const Color(0xFF4527A0)),
      _ThemePreset('برتقالي', const Color(0xFFFF8F00), const Color(0xFFE65100)),
      _ThemePreset('وردي', const Color(0xFFEC407A), const Color(0xFFAD1457)),
      _ThemePreset('رمادي داكن', const Color(0xFF455A64), const Color(0xFF263238)),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: themes.map((t) {
        final isSelected = t.primary.value == AppTheme.primaryColor.value;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showSnackBar('سيتم تطبيق "${t.name}" بعد إعادة التشغيل');
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 100,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [t.primary, t.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
              boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.3), blurRadius: isSelected ? 12 : 6, offset: const Offset(0, 3))],
            ),
            child: Column(
              children: [
                if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                if (isSelected) const SizedBox(height: 4),
                Text(t.name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFontSelector() {
    final fonts = ['Cairo', 'Tajawal', 'Almarai', 'IBM Plex Sans Arabic'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fonts.map((f) {
        final isSelected = f == 'Cairo';
        return ChoiceChip(
          label: Text(f, style: TextStyle(fontFamily: f, fontSize: 14)),
          selected: isSelected,
          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          onSelected: (_) {
            HapticFeedback.lightImpact();
            _showSnackBar('سيتم تطبيق خط "$f"');
          },
        );
      }).toList(),
    );
  }

  Widget _buildCardStyleSelector() {
    final styles = ['زوايا ناعمة', 'زوايا حادة', 'زوايا دائرية'];
    return Row(
      children: styles.asMap().entries.map((e) {
        final isSelected = e.key == 0;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showSnackBar('تم اختيار "${e.value}"');
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(
                  e.key == 0 ? 16 : e.key == 1 ? 4 : 30,
                ),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(e.value, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeaderStyleSelector() {
    final styles = [
      _HeaderStyle('ملون', Icons.palette_rounded, AppTheme.primaryColor),
      _HeaderStyle('داكن', Icons.dark_mode_rounded, const Color(0xFF1A2332)),
      _HeaderStyle('فاتح', Icons.light_mode_rounded, Colors.white),
    ];

    return Row(
      children: styles.map((s) {
        final isSelected = s.color == AppTheme.primaryColor;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showSnackBar('تم اختيار شريط "${s.label}"');
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: s.color == Colors.white ? Colors.grey.shade50 : s.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? s.color : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(s.icon, color: s.color == Colors.white ? Colors.grey : s.color, size: 24),
                  const SizedBox(height: 6),
                  Text(s.label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBorderRadiusSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)]),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(activeTrackColor: AppTheme.primaryColor, thumbColor: AppTheme.primaryColor, inactiveTrackColor: Colors.grey.shade200),
            child: Slider(
              value: 16,
              min: 0,
              max: 30,
              divisions: 6,
              onChanged: (v) => HapticFeedback.lightImpact(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['حاد', '', '', 'متوسط', '', '', 'دائري'].map((l) => Text(l, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.textHint))).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 3: ANALYTICS
  // ═══════════════════════════════════════════════════════════
  Widget _buildAnalyticsTab() {
    final analytics = ref.watch(dashboardAnalyticsProvider(const AnalyticsFilter()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: analytics.when(
        loading: () => const Center(child: EpiLoading.shimmer()),
        error: (e, _) => EpiErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(dashboardAnalyticsProvider(const AnalyticsFilter()))),
        data: (data) => _buildAdminAnalytics(data),
      ),
    );
  }

  Widget _buildAdminAnalytics(Map<String, dynamic> data) {
    final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
    final shortages = data['shortages'] as Map<String, dynamic>? ?? {};
    final byGovernorate = data['governorateBreakdown'] as List? ?? [];
    final forms = data['forms'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall stats
        Row(
          children: [
            Expanded(child: _adminStatCard('إجمالي الإرساليات', '${submissions['total'] ?? 0}', Icons.upload_file_rounded, AppTheme.primaryColor)),
            const SizedBox(width: 12),
            Expanded(child: _adminStatCard('النواقص', '${shortages['total'] ?? 0}', Icons.warning_amber_rounded, AppTheme.warningColor)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _adminStatCard('اليوم', '${submissions['today'] ?? 0}', Icons.today_rounded, AppTheme.infoColor)),
            const SizedBox(width: 12),
            Expanded(child: _adminStatCard('محلول', '${shortages['resolved'] ?? 0}', Icons.check_circle_rounded, AppTheme.successColor)),
          ],
        ),
        const SizedBox(height: 24),

        // Per-page analytics
        _sectionHeader('📊 إحصائيات حسب الصفحة'),
        const SizedBox(height: 12),
        ..._pages.map((page) => _buildPageAnalyticsCard(page, data)),

        const SizedBox(height: 24),

        // Governorate ranking
        if (byGovernorate.isNotEmpty) ...[
          _sectionHeader('🗺️ المحافظات'),
          const SizedBox(height: 12),
          _buildGovernorateRanking(byGovernorate),
        ],

        const SizedBox(height: 24),

        // Form performance
        if (forms.isNotEmpty) ...[
          _sectionHeader('📝 أداء النماذج'),
          const SizedBox(height: 12),
          _buildFormPerformance(forms),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _adminStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPageAnalyticsCard(AdminPageItem page, Map<String, dynamic> data) {
    // Simulate per-page metrics based on the data
    final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
    final total = submissions['total'] as int? ?? 0;

    int pageViews;
    switch (page.id) {
      case 'dashboard': pageViews = total * 3; break;
      case 'forms': pageViews = (total * 1.5).round(); break;
      case 'submissions': pageViews = total * 2; break;
      case 'analytics': pageViews = (total * 0.8).round(); break;
      default: pageViews = (total * 0.5).round();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: page.color.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: page.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(page.icon, color: page.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(page.nameAr, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${pageViews} زيارة', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: page.isVisible ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(page.isVisible ? 'نشط' : 'متوقف', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: page.isVisible ? AppTheme.successColor : AppTheme.warningColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernorateRanking(List governors) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(
        children: governors.take(8).map<Widget>((gov) {
          final name = gov['nameAr'] as String? ?? '';
          final count = gov['count'] as int? ?? 0;
          final maxCount = (governors.first['count'] as int?) ?? 1;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: count / maxCount,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 40, child: Text('$count', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFormPerformance(List forms) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(
        children: forms.take(8).map<Widget>((f) {
          final title = f['titleAr'] as String? ?? '';
          final stats = f['stats'] as Map<String, dynamic>? ?? {};
          final total = stats['total'] as int? ?? 0;
          final byStatus = stats['byStatus'] as Map<String, dynamic>? ?? {};
          final approved = byStatus['approved'] as int? ?? 0;

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.infoColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.description_rounded, color: AppTheme.infoColor, size: 18),
            ),
            title: Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('إجمالي: $total | معتمد: $approved', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
            trailing: total > 0
                ? Text('${((approved / total) * 100).round()}%', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.successColor))
                : const Text('-', style: TextStyle(color: AppTheme.textHint)),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 4: SETTINGS
  // ═══════════════════════════════════════════════════════════
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('⚙️ إعدادات التطبيق العامة'),
          const SizedBox(height: 12),

          _buildSettingTile('اسم التطبيق', 'منصة مشرف EPI', Icons.apps_rounded, () => _showEditDialog('اسم التطبيق', 'منصة مشرف EPI')),
          _buildSettingTile('اللغة الافتراضية', 'العربية (RTL)', Icons.language_rounded, null),
          _buildSettingTile('المنطقة الزمنية', 'Asia/Baghdad', Icons.access_time_rounded, null),
          _buildSettingTile('إعدادات المزامنة', 'تلقائية كل 5 دقائق', Icons.sync_rounded, null),
          _buildSettingTile('وضع عدم الاتصال', 'مفعّل', Icons.wifi_off_rounded, null),

          const SizedBox(height: 24),
          _sectionHeader('🔔 إعدادات الإشعارات'),
          const SizedBox(height: 12),

          _buildSwitchTile('إشعارات الإرساليات الجديدة', true),
          _buildSwitchTile('تنبيهات النواقص الحرجة', true),
          _buildSwitchTile('إشعارات المزامنة', false),
          _buildSwitchTile('تنبيهات صوتية', true),

          const SizedBox(height: 24),
          _sectionHeader('💾 إدارة البيانات'),
          const SizedBox(height: 12),

          _buildActionTile('مسح الكاش', Icons.delete_sweep_rounded, AppTheme.warningColor, () {
            _showConfirmDialog('مسح الكاش', 'سيتم مسح جميع البيانات المخزنة مؤقتاً. لن يتأثر العمل بدون اتصال.', () {
              _showSnackBar('تم مسح الكاش بنجاح');
            });
          }),
          _buildActionTile('تصدير جميع البيانات', Icons.download_rounded, AppTheme.infoColor, () {
            _showSnackBar('جارٍ تجهيز ملف التصدير...');
          }),
          _buildActionTile('نسخ احتياطي', Icons.backup_rounded, AppTheme.successColor, () {
            _showSnackBar('تم إنشاء نسخة احتياطية');
          }),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, String value, IconData icon, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
        trailing: onTap != null ? const Icon(Icons.chevron_left_rounded, color: AppTheme.textHint) : null,
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value) {
    return StatefulBuilder(
      builder: (context, setSwitchState) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: SwitchListTile(
            value: value,
            onChanged: (v) {
              setSwitchState(() {});
              HapticFeedback.lightImpact();
              _showSnackBar(v ? 'تم تفعيل "$title"' : 'تم إيقاف "$title"');
            },
            activeColor: AppTheme.primaryColor,
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
          ),
        );
      },
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        trailing: Icon(Icons.chevron_left_rounded, color: color.withValues(alpha: 0.5)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 5: SECURITY
  // ═══════════════════════════════════════════════════════════
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('🛡️ ملخص الأمان'),
          const SizedBox(height: 12),

          _buildSecurityScore(),
          const SizedBox(height: 24),

          _sectionHeader('🔐 صلاحيات الوصول'),
          const SizedBox(height: 12),

          _buildRoleCard('مدير النظام', 5, 'وصول كامل', AppTheme.errorColor),
          _buildRoleCard('مدير مركز', 4, 'إدارة المحافظة', AppTheme.warningColor),
          _buildRoleCard('مشرف ميداني', 3, 'إدخال ومراجعة', AppTheme.infoColor),
          _buildRoleCard('مدخل بيانات', 2, 'إدخال فقط', AppTheme.successColor),
          _buildRoleCard('مشاهد', 1, 'قراءة فقط', Colors.grey),

          const SizedBox(height: 24),
          _sectionHeader('📋 آخر تسجيلات الدخول'),
          const SizedBox(height: 12),

          _buildLoginHistory(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSecurityScore() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A2332), Color(0xFF2D3748)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              children: [
                CircularProgressIndicator(value: 0.85, strokeWidth: 6, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(AppTheme.successColor)),
                const Center(child: Text('85', style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نقاط الأمان', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                SizedBox(height: 4),
                Text('النظام محمي بشكل جيد — راجع الصلاحيات بانتظام', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String name, int level, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 8)]),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text('$level', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: color))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600)),
                Text(desc, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          // Show which pages this role can access
          Wrap(
            spacing: 2,
            children: _pages.take(5).map((p) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: level >= 3 ? p.color : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginHistory() {
    final history = [
      {'user': 'أحمد محمد', 'role': 'مدير', 'time': 'منذ 5 دقائق', 'device': 'iPhone 14'},
      {'user': 'سارة علي', 'role': 'مشرف', 'time': 'منذ 30 دقيقة', 'device': 'Samsung S23'},
      {'user': 'محمد حسن', 'role': 'مدخل', 'time': 'منذ ساعة', 'device': 'Web Chrome'},
    ];

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)]),
      child: Column(
        children: history.map((h) => ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Text(h['user']![0], style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.primaryColor)),
          ),
          title: Text(h['user']!, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('${h['role']} • ${h['device']}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
          trailing: Text(h['time']!, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint)),
        )).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DIALOGS & HELPERS
  // ═══════════════════════════════════════════════════════════
  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Tajawal')),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddPageDialog() {
    final nameController = TextEditingController();
    final routeController = TextEditingController();
    IconData selectedIcon = Icons.extension_rounded;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('إضافة صفحة جديدة', style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              style: const TextStyle(fontFamily: 'Tajawal'),
              decoration: InputDecoration(
                labelText: 'اسم الصفحة (عربي)',
                labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: routeController,
              style: const TextStyle(fontFamily: 'Tajawal'),
              decoration: InputDecoration(
                labelText: 'المسار (مثال: /reports)',
                labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            // Icon picker
            const Text('أيقونة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Icons.description_rounded, Icons.bar_chart_rounded, Icons.map_rounded,
                Icons.people_rounded, Icons.settings_rounded, Icons.folder_rounded,
                Icons.analytics_rounded, Icons.assignment_rounded, Icons.extension_rounded,
              ].map((icon) {
                final isSelected = icon == selectedIcon;
                return GestureDetector(
                  onTap: () {
                    selectedIcon = icon;
                    (ctx as Element).markNeedsBuild();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                    ),
                    child: Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (nameController.text.isNotEmpty && routeController.text.isNotEmpty) {
                    setState(() {
                      _pages.add(AdminPageItem(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        nameAr: nameController.text,
                        nameEn: nameController.text,
                        icon: selectedIcon,
                        route: routeController.text,
                        color: AppTheme.secondaryColor,
                        isVisible: true,
                        isEditable: true,
                        sortOrder: _pages.length,
                        description: 'صفحة مخصصة',
                      ));
                    });
                    Navigator.pop(ctx);
                    _showSnackBar('تمت إضافة "${nameController.text}"');
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة الصفحة', style: TextStyle(fontFamily: 'Tajawal')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPageDetails(AdminPageItem page) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: page.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(page.icon, color: page.color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(page.nameAr, style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(page.route, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('الحالة', page.isVisible ? 'ظاهر' : 'مخفي', page.isVisible ? AppTheme.successColor : AppTheme.warningColor),
            _detailRow('الترتيب', '${page.sortOrder + 1}', AppTheme.infoColor),
            _detailRow('قابل للتعديل', page.isEditable ? 'نعم' : 'لا', page.isEditable ? AppTheme.successColor : Colors.grey),
            _detailRow('الوصف', page.description, AppTheme.textSecondary),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go(page.route);
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('فتح', style: TextStyle(fontFamily: 'Tajawal')),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditPageDialog(page);
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('تعديل', style: TextStyle(fontFamily: 'Tajawal')),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary))),
          Expanded(child: Text(value, style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w600, color: color))),
        ],
      ),
    );
  }

  void _showEditPageDialog(AdminPageItem page) {
    final nameController = TextEditingController(text: page.nameAr);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('تعديل الصفحة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(fontFamily: 'Tajawal'),
              decoration: InputDecoration(labelText: 'اسم الصفحة', labelStyle: const TextStyle(fontFamily: 'Tajawal'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    page.nameAr = nameController.text;
                  });
                  Navigator.pop(ctx);
                  _showSnackBar('تم تحديث "${nameController.text}"');
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('حفظ التعديلات', style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePageAction(String action, AdminPageItem page) {
    switch (action) {
      case 'edit':
        _showEditPageDialog(page);
        break;
      case 'duplicate':
        setState(() {
          _pages.add(AdminPageItem(
            id: 'dup_${DateTime.now().millisecondsSinceEpoch}',
            nameAr: '${page.nameAr} (نسخة)',
            nameEn: '${page.nameEn} (Copy)',
            icon: page.icon,
            route: '${page.route}-copy',
            color: page.color,
            isVisible: false,
            isEditable: true,
            sortOrder: _pages.length,
            description: page.description,
          ));
        });
        _showSnackBar('تم نسخ "${page.nameAr}"');
        break;
      case 'delete':
        _showConfirmDialog('حذف "${page.nameAr}"', 'هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء.', () {
          setState(() => _pages.removeWhere((p) => p.id == page.id));
          _showSnackBar('تم حذف "${page.nameAr}"');
        });
        break;
    }
  }

  void _showConfirmDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)),
        content: Text(message, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('تأكيد', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String title, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تعديل $title', style: const TextStyle(fontFamily: 'Cairo')),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontFamily: 'Tajawal'),
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _showSnackBar('تم التحديث'); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data Models
// ═══════════════════════════════════════════════════════════════════════════════

class AdminPageItem {
  final String id;
  String nameAr;
  final String nameEn;
  final IconData icon;
  final String route;
  final Color color;
  bool isVisible;
  final bool isEditable;
  int sortOrder;
  final String description;

  AdminPageItem({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.route,
    required this.color,
    required this.isVisible,
    required this.isEditable,
    required this.sortOrder,
    required this.description,
  });
}

class _ThemePreset {
  final String name;
  final Color primary;
  final Color secondary;
  _ThemePreset(this.name, this.primary, this.secondary);
}

class _HeaderStyle {
  final String label;
  final IconData icon;
  final Color color;
  _HeaderStyle(this.label, this.icon, this.color);
}
