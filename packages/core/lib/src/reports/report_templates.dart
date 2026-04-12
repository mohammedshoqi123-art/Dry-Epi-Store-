/// Pre-built report templates for common EPI reporting needs.
/// Each template defines sections, columns, and chart configurations.
class ReportTemplates {
  /// Vaccination coverage report by governorate/district
  static ReportTemplate get vaccinationCoverage => ReportTemplate(
        id: 'vaccination_coverage',
        name: 'تقرير تغطية التطعيم',
        description: 'تقرير مفصل عن نسب تغطية التطعيم حسب المنطقة',
        icon: '📊',
        sections: [
          ReportSection(
            title: 'ملخص تنفيذي',
            type: SectionType.summary,
          ),
          ReportSection(
            title: 'التغطية حسب المحافظة',
            type: SectionType.table,
            config: {
              'columns': ['المحافظة', 'التغطية %', 'الهدف %', 'الحالة'],
              'groupBy': 'governorate',
              'threshold': 80,
            },
          ),
          ReportSection(
            title: 'الاتجاهات الشهرية',
            type: SectionType.chart,
            config: {
              'chartType': 'line',
              'xAxis': 'month',
              'yAxis': 'coverage_rate',
            },
          ),
          ReportSection(
            title: 'النقاط الحرجة',
            type: SectionType.critical,
            config: {
              'threshold': 80,
              'alertType': 'below_target',
            },
          ),
        ],
      );

  /// Dropout analysis report
  static ReportTemplate get dropoutAnalysis => ReportTemplate(
        id: 'dropout_analysis',
        name: 'تحليل حالات الانسحاب',
        description: 'تحليل مسببات الانسحاب من التطعيم',
        icon: '📉',
        sections: [
          ReportSection(
            title: 'نسب الانسحاب الكلية',
            type: SectionType.summary,
          ),
          ReportSection(
            title: 'أسباب الانسحاب',
            type: SectionType.pieChart,
            config: {
              'dataField': 'dropout_reason',
              'valueField': 'count',
            },
          ),
          ReportSection(
            title: 'التوزيع الجغرافي',
            type: SectionType.map,
            config: {
              'mapType': 'heatmap',
              'dataField': 'dropout_rate',
            },
          ),
        ],
      );

  /// Supply shortages report
  static ReportTemplate get supplyShortages => ReportTemplate(
        id: 'supply_shortages',
        name: 'تقرير نواقص التجهيزات',
        description: 'تقرير شامل عن نواقص اللقاحات والمستلزمات',
        icon: '⚠️',
        sections: [
          ReportSection(
            title: 'ملخص النواقص',
            type: SectionType.summary,
          ),
          ReportSection(
            title: 'النواقص حسب الشدة',
            type: SectionType.barChart,
            config: {
              'groupBy': 'severity',
              'categories': ['حرج', 'عالي', 'متوسط', 'منخفض'],
              'colors': ['#FF0000', '#FF6600', '#FFCC00', '#00CC00'],
            },
          ),
          ReportSection(
            title: 'النواقص حسب المحافظة',
            type: SectionType.table,
            config: {
              'columns': ['المحافظة', 'إجمالي', 'حرج', 'محلول'],
              'groupBy': 'governorate',
            },
          ),
        ],
      );

  /// Daily field activity report
  static ReportTemplate get dailyActivity => ReportTemplate(
        id: 'daily_activity',
        name: 'تقرير النشاط اليومي',
        description: 'ملخص يومي لأنشطة فرق العمل الميدانية',
        icon: '📅',
        sections: [
          ReportSection(
            title: 'ملخص اليوم',
            type: SectionType.summary,
          ),
          ReportSection(
            title: 'الإرساليات حسب الوقت',
            type: SectionType.chart,
            config: {
              'chartType': 'bar',
              'xAxis': 'hour',
              'yAxis': 'submissions_count',
            },
          ),
          ReportSection(
            title: 'أداء المستخدمين',
            type: SectionType.table,
            config: {
              'columns': ['المستخدم', 'إرساليات', 'مرفوضة', 'النسبة'],
              'groupBy': 'user',
              'sortBy': 'submissions_count',
            },
          ),
        ],
      );

  /// Comprehensive KPI report
  static ReportTemplate get kpiDashboard => ReportTemplate(
        id: 'kpi_dashboard',
        name: 'لوحة مؤشرات الأداء',
        description: 'تقرير شامل بمؤشرات الأداء الرئيسية',
        icon: '🎯',
        sections: [
          ReportSection(
            title: 'المؤشرات الرئيسية',
            type: SectionType.kpiCards,
            config: {
              'kpis': [
                {'name': 'نسبة التغطية', 'field': 'coverage_rate', 'unit': '%', 'target': 95},
                {'name': 'معدل الانسحاب', 'field': 'dropout_rate', 'unit': '%', 'target': 5},
                {'name': 'الإرساليات اليوم', 'field': 'daily_submissions', 'unit': '', 'target': 100},
                {'name': 'النواقص الحرجة', 'field': 'critical_shortages', 'unit': '', 'target': 0},
              ],
            },
          ),
          ReportSection(
            title: 'مقارنة الفترات',
            type: SectionType.comparison,
            config: {
              'periods': ['current_week', 'previous_week', 'current_month'],
            },
          ),
        ],
      );

  /// Get all available templates
  static List<ReportTemplate> get all => [
        vaccinationCoverage,
        dropoutAnalysis,
        supplyShortages,
        dailyActivity,
        kpiDashboard,
      ];

  /// Get template by ID
  static ReportTemplate? getById(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Report template definition
class ReportTemplate {
  final String id;
  final String name;
  final String description;
  final String icon;
  final List<ReportSection> sections;

  ReportTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.sections,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'sections': sections.map((s) => s.toJson()).toList(),
      };
}

/// Report section definition
class ReportSection {
  final String title;
  final SectionType type;
  final Map<String, dynamic> config;

  ReportSection({
    required this.title,
    required this.type,
    this.config = const {},
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'type': type.name,
        'config': config,
      };
}

/// Types of report sections
enum SectionType {
  summary,
  table,
  chart,
  barChart,
  lineChart,
  pieChart,
  map,
  critical,
  kpiCards,
  comparison,
}

/// Arabic labels for section types
extension SectionTypeExt on SectionType {
  String get labelAr {
    switch (this) {
      case SectionType.summary:
        return 'ملخص';
      case SectionType.table:
        return 'جدول';
      case SectionType.chart:
        return 'رسم بياني';
      case SectionType.barChart:
        return 'رسم أعمدة';
      case SectionType.lineChart:
        return 'رسم خطي';
      case SectionType.pieChart:
        return 'رسم دائري';
      case SectionType.map:
        return 'خريطة';
      case SectionType.critical:
        return 'نقاط حرجة';
      case SectionType.kpiCards:
        return 'بطاقات مؤشرات';
      case SectionType.comparison:
        return 'مقارنة';
    }
  }
}
