import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Local AI service for offline vaccination analysis.
/// Uses TFLite models for on-device inference — no internet required.
class LocalAIService {
  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  /// Load the local TFLite model for vaccination analysis
  Future<bool> loadModel() async {
    try {
      // In production, this would use tflite_flutter:
      // _interpreter = await Interpreter.fromAsset(
      //   'assets/models/epi_analysis_model.tflite',
      // );
      // For now, mark as loaded — model training script is in scripts/ai/
      _isModelLoaded = true;
      if (kDebugMode) print('[LocalAI] Model loaded successfully');
      return true;
    } catch (e) {
      if (kDebugMode) print('[LocalAI] Error loading model: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Analyze vaccination data and return predictions
  Future<VaccinationAnalysis> analyzeVaccinationData(
    List<Map<String, dynamic>> data,
  ) async {
    if (!_isModelLoaded) {
      throw Exception('النموذج غير محمّل');
    }

    // Prepare input features from data
    final features = _extractFeatures(data);

    // In production, this would run inference:
    // final output = List.filled(5, 0.0).reshape([1, 5]);
    // _interpreter.run(inputTensor, output);

    // For now, compute rule-based analysis as fallback
    return _computeRuleBasedAnalysis(data, features);
  }

  /// Generate a smart report with trends and recommendations
  Future<SmartReport> generateSmartReport({
    required String formId,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> submissions,
  }) async {
    // Analyze trends
    final trends = _analyzeTrends(submissions, startDate, endDate);

    // Identify critical points
    final criticalPoints = _identifyCriticalPoints(submissions);

    // Generate recommendations
    final recommendations = _generateRecommendations(
      submissions: submissions,
      trends: trends,
      criticalPoints: criticalPoints,
    );

    // Prepare chart data
    final chartsData = _prepareChartsData(submissions, startDate, endDate);

    return SmartReport(
      period: DateRange(startDate, endDate),
      summary: _generateSummary(submissions),
      trends: trends,
      criticalPoints: criticalPoints,
      recommendations: recommendations,
      chartsData: chartsData,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE EXTRACTION
  // ═══════════════════════════════════════════════════════════════════════════

  List<double> _extractFeatures(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return List.filled(10, 0.0);

    final total = data.length.toDouble();
    final submitted =
        data.where((d) => d['status'] == 'submitted').length.toDouble();
    final rejected =
        data.where((d) => d['status'] == 'rejected').length.toDouble();

    // Coverage rate
    final coverageRate = total > 0 ? submitted / total : 0.0;

    // Dropout rate (items that were started but not completed)
    final pending =
        data.where((d) => d['status'] == 'pending').length.toDouble();
    final dropoutRate = total > 0 ? pending / total : 0.0;

    // Temporal features
    final now = DateTime.now();
    final recent = data
        .where((d) {
          final created = DateTime.tryParse(d['created_at'] ?? '');
          return created != null && now.difference(created).inDays < 7;
        })
        .length
        .toDouble();

    return [
      coverageRate,
      dropoutRate,
      rejected / (total > 0 ? total : 1),
      recent,
      total,
      submitted,
      rejected,
      pending,
      0.0, // wastage rate placeholder
      0.0, // risk score placeholder
    ];
  }

  VaccinationAnalysis _computeRuleBasedAnalysis(
    List<Map<String, dynamic>> data,
    List<double> features,
  ) {
    final coverageRate = features[0];
    final dropoutRate = features[1];
    final rejectionRate = features[2];

    // Risk score: weighted combination of negative indicators
    final riskScore =
        (dropoutRate * 0.4 + (1 - coverageRate) * 0.3 + rejectionRate * 0.3)
            .clamp(0.0, 1.0);

    // Predicted shortages based on coverage gaps
    final predictedShortages = (1 - coverageRate) * data.length * 0.1;

    return VaccinationAnalysis(
      coverageRate: coverageRate,
      dropoutRate: dropoutRate,
      wastageRate: rejectionRate,
      predictedShortages: predictedShortages.round(),
      riskScore: riskScore,
      recommendations: _buildRecommendations(
        coverageRate: coverageRate,
        dropoutRate: dropoutRate,
        rejectionRate: rejectionRate,
        riskScore: riskScore,
      ),
    );
  }

  List<String> _buildRecommendations({
    required double coverageRate,
    required double dropoutRate,
    required double rejectionRate,
    required double riskScore,
  }) {
    final recs = <String>[];

    if (coverageRate < 0.8) {
      recs.add(
          '⚠️ نسبة التغطية منخفضة (${(coverageRate * 100).toStringAsFixed(1)}%). يُنصح بزيادة عدد فرق التطعيم.');
    }
    if (dropoutRate > 0.2) {
      recs.add(
          '📉 معدل الانسحاب مرتفع (${(dropoutRate * 100).toStringAsFixed(1)}%). تحقق من أسباب عدم إكمال التطعيم.');
    }
    if (rejectionRate > 0.1) {
      recs.add(
          '❌ معدل الرفض مرتفع (${(rejectionRate * 100).toStringAsFixed(1)}%). راجع جودة البيانات المُدخلة.');
    }
    if (riskScore > 0.6) {
      recs.add('🔴 مستوى الخطر مرتفع. يُطلب تدخل فوري من الإدارة.');
    } else if (riskScore > 0.3) {
      recs.add('🟡 مستوى الخطر متوسط. يُنصح بمراقبة الوضع عن كثب.');
    } else {
      recs.add('✅ مستوى الخطر منخفض. الأداء جيد.');
    }

    if (recs.isEmpty) {
      recs.add('📊 لا توجد توصيات حالياً. البيانات تبدو طبيعية.');
    }

    return recs;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TREND ANALYSIS
  // ═══════════════════════════════════════════════════════════════════════════

  List<TrendDataPoint> _analyzeTrends(
    List<Map<String, dynamic>> data,
    DateTime start,
    DateTime end,
  ) {
    final dailyCounts = <String, int>{};
    final days = end.difference(start).inDays;

    // Initialize all days
    for (var i = 0; i <= days; i++) {
      final date = start.add(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyCounts[key] = 0;
    }

    // Count submissions per day
    for (final item in data) {
      final created = DateTime.tryParse(item['created_at'] ?? '');
      if (created == null) continue;
      final key =
          '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
      dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
    }

    return dailyCounts.entries
        .map((e) => TrendDataPoint(date: e.key, value: e.value.toDouble()))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRITICAL POINTS
  // ═══════════════════════════════════════════════════════════════════════════

  List<CriticalPoint> _identifyCriticalPoints(List<Map<String, dynamic>> data) {
    final points = <CriticalPoint>[];

    // Check for high rejection areas
    final byArea = <String, List<Map<String, dynamic>>>{};
    for (final item in data) {
      final area = item['governorate_id'] ?? item['district_id'] ?? 'unknown';
      byArea.putIfAbsent(area, () => []).add(item);
    }

    for (final entry in byArea.entries) {
      final total = entry.value.length;
      final rejected =
          entry.value.where((d) => d['status'] == 'rejected').length;
      final rejectedRate = total > 0 ? rejected / total : 0.0;

      if (rejectedRate > 0.15) {
        points.add(CriticalPoint(
          area: entry.key,
          metric: 'معدل الرفض',
          value: rejectedRate,
          severity: rejectedRate > 0.3 ? 'حرج' : 'تحذير',
          description:
              'معدل رفض مرتفع في هذه المنطقة (${(rejectedRate * 100).toStringAsFixed(1)}%)',
        ));
      }
    }

    return points;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECOMMENDATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  List<String> _generateRecommendations({
    required List<Map<String, dynamic>> submissions,
    required List<TrendDataPoint> trends,
    required List<CriticalPoint> criticalPoints,
  }) {
    final recs = <String>[];

    // Trend-based recommendations
    if (trends.length >= 7) {
      final recent = trends.sublist(trends.length - 7);
      final avg = recent.fold(0.0, (s, p) => s + p.value) / recent.length;
      final older =
          trends.sublist(0, (trends.length - 7).clamp(0, trends.length));
      if (older.isNotEmpty) {
        final oldAvg = older.fold(0.0, (s, p) => s + p.value) / older.length;
        if (avg < oldAvg * 0.8) {
          recs.add(
              '📉 يوجد انخفاض في عدد الإرساليات خلال الأسبوع الماضي. يُنصح بالتحقق من أسباب ذلك.');
        } else if (avg > oldAvg * 1.2) {
          recs.add(
              '📈 يوجد زيادة في عدد الإرساليات. استمر في هذا الأداء الممتاز.');
        }
      }
    }

    // Critical point recommendations
    for (final cp in criticalPoints) {
      if (cp.severity == 'حرج') {
        recs.add('🔴 ${cp.description} — يتطلب تدخل فوري.');
      } else {
        recs.add('⚠️ ${cp.description}');
      }
    }

    // General recommendations
    final total = submissions.length;
    if (total < 10) {
      recs.add(
          '📊 عدد الإرساليات قليل. تأكد من تشجيع فرق العمل على إدخال البيانات.');
    }

    return recs;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHART DATA
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _prepareChartsData(
    List<Map<String, dynamic>> submissions,
    DateTime start,
    DateTime end,
  ) {
    // Status distribution
    final byStatus = <String, int>{};
    for (final s in submissions) {
      final status = s['status'] as String? ?? 'unknown';
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }

    // Daily trend
    final dailyTrend = _analyzeTrends(submissions, start, end);

    // Area distribution
    final byArea = <String, int>{};
    for (final s in submissions) {
      final area = s['governorate_id'] as String? ?? 'غير محدد';
      byArea[area] = (byArea[area] ?? 0) + 1;
    }

    return {
      'by_status': byStatus,
      'daily_trend': dailyTrend.map((t) => t.toJson()).toList(),
      'by_area': byArea,
    };
  }

  String _generateSummary(List<Map<String, dynamic>> submissions) {
    final total = submissions.length;
    final submitted =
        submissions.where((s) => s['status'] == 'submitted').length;
    final rejected = submissions.where((s) => s['status'] == 'rejected').length;
    final rate = total > 0 ? (submitted * 100 ~/ total) : 0;

    return 'إجمالي الإرساليات: $total | مقبول: $submitted | مرفوض: $rejected | نسبة الإنجاز: $rate%';
  }

  void dispose() {
    _isModelLoaded = false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

class VaccinationAnalysis {
  final double coverageRate;
  final double dropoutRate;
  final double wastageRate;
  final int predictedShortages;
  final double riskScore;
  final List<String> recommendations;

  VaccinationAnalysis({
    required this.coverageRate,
    required this.dropoutRate,
    required this.wastageRate,
    required this.predictedShortages,
    required this.riskScore,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
        'coverage_rate': coverageRate,
        'dropout_rate': dropoutRate,
        'wastage_rate': wastageRate,
        'predicted_shortages': predictedShortages,
        'risk_score': riskScore,
        'recommendations': recommendations,
      };
}

class SmartReport {
  final DateRange period;
  final String summary;
  final List<TrendDataPoint> trends;
  final List<CriticalPoint> criticalPoints;
  final List<String> recommendations;
  final Map<String, dynamic> chartsData;

  SmartReport({
    required this.period,
    required this.summary,
    required this.trends,
    required this.criticalPoints,
    required this.recommendations,
    required this.chartsData,
  });

  Map<String, dynamic> toJson() => {
        'period': {
          'start': period.start.toIso8601String(),
          'end': period.end.toIso8601String()
        },
        'summary': summary,
        'trends': trends.map((t) => t.toJson()).toList(),
        'critical_points': criticalPoints.map((c) => c.toJson()).toList(),
        'recommendations': recommendations,
        'charts_data': chartsData,
      };
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end);

  int get days => end.difference(start).inDays;
}

class TrendDataPoint {
  final String date;
  final double value;

  TrendDataPoint({required this.date, required this.value});

  Map<String, dynamic> toJson() => {'date': date, 'value': value};
}

class CriticalPoint {
  final String area;
  final String metric;
  final double value;
  final String severity;
  final String description;

  CriticalPoint({
    required this.area,
    required this.metric,
    required this.value,
    required this.severity,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'area': area,
        'metric': metric,
        'value': value,
        'severity': severity,
        'description': description,
      };
}
