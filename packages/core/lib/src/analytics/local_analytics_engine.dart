import 'dart:math';

/// Local analytics engine for on-device data analysis.
/// Provides statistical analysis, anomaly detection, and simple predictions
/// without requiring an external AI API call.
class LocalAnalyticsEngine {
  // ─── Statistical Analysis ─────────────────────────────────────────────────

  /// Compute mean of a numeric list
  static double mean(List<num> data) {
    if (data.isEmpty) return 0;
    return data.reduce((a, b) => a + b) / data.length;
  }

  /// Compute standard deviation
  static double standardDeviation(List<num> data) {
    if (data.length < 2) return 0;
    final avg = mean(data);
    final variance = data.fold(0.0, (sum, v) => sum + pow(v - avg, 2)) / (data.length - 1);
    return sqrt(variance);
  }

  /// Compute median
  static double median(List<num> data) {
    if (data.isEmpty) return 0;
    final sorted = List<num>.from(data)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid].toDouble();
    return ((sorted[mid - 1] + sorted[mid]) / 2).toDouble();
  }

  // ─── Anomaly Detection ────────────────────────────────────────────────────

  /// Detect anomalies using Z-score method (|z| > threshold).
  /// Returns indices of anomalous data points.
  static List<int> detectAnomalies(List<num> data, {double threshold = 2.0}) {
    if (data.length < 3) return [];
    final avg = mean(data);
    final sd = standardDeviation(data);
    if (sd == 0) return [];

    final anomalies = <int>[];
    for (var i = 0; i < data.length; i++) {
      final z = (data[i] - avg).abs() / sd;
      if (z > threshold) anomalies.add(i);
    }
    return anomalies;
  }

  /// Detect sudden drops or spikes in time-series data.
  /// Returns indices where change exceeds the threshold.
  static List<int> detectSuddenChanges(List<num> data, {double changeThreshold = 0.5}) {
    if (data.length < 2) return [];
    final changes = <int>[];

    for (var i = 1; i < data.length; i++) {
      final prev = data[i - 1];
      if (prev == 0) continue;
      final change = (data[i] - prev) / prev;
      if (change.abs() > changeThreshold) {
        changes.add(i);
      }
    }
    return changes;
  }

  // ─── Trend Analysis ───────────────────────────────────────────────────────

  /// Simple linear regression: returns slope and intercept.
  /// Positive slope = upward trend, negative = downward.
  static ({double slope, double intercept, double r2}) linearRegression(List<num> y) {
    final n = y.length;
    if (n < 2) return (slope: 0.0, intercept: 0.0, r2: 0.0);

    final x = List.generate(n, (i) => i.toDouble());
    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = y.map((v) => v.toDouble()).reduce((a, b) => a + b) / n;

    double ssXY = 0, ssXX = 0, ssYY = 0;
    for (var i = 0; i < n; i++) {
      ssXY += (x[i] - xMean) * (y[i].toDouble() - yMean);
      ssXX += (x[i] - xMean) * (x[i] - xMean);
      ssYY += (y[i].toDouble() - yMean) * (y[i].toDouble() - yMean);
    }

    if (ssXX == 0) return (slope: 0.0, intercept: yMean, r2: 0.0);

    final slope = ssXY / ssXX;
    final intercept = yMean - slope * xMean;

    // R-squared
    final ssRes = y.fold(0.0, (sum, v) {
      final predicted = slope * y.indexOf(v) + intercept;
      return sum + pow(v.toDouble() - predicted, 2);
    });
    final r2 = ssYY > 0 ? 1 - (ssRes / ssYY) : 0.0;

    return (slope: slope, intercept: intercept, r2: r2.clamp(0.0, 1.0));
  }

  /// Predict next N values using linear regression.
  static List<double> predictNext(List<num> data, int count) {
    final regression = linearRegression(data);
    final n = data.length;
    return List.generate(count, (i) {
      return regression.slope * (n + i) + regression.intercept;
    });
  }

  // ─── Pattern Detection ────────────────────────────────────────────────────

  /// Identify top-N categories by frequency from a list.
  static List<MapEntry<String, int>> topCategories(List<String> data, {int topN = 5}) {
    final freq = <String, int>{};
    for (final item in data) {
      freq[item] = (freq[item] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(topN).toList();
  }

  /// Compute a health score (0-100) based on resolution rate and critical count.
  static int healthScore({
    required int totalShortages,
    required int resolvedShortages,
    required int criticalShortages,
    required int totalSubmissions,
  }) {
    if (totalShortages == 0 && totalSubmissions == 0) return 50;

    // Resolution rate: 0-40 points
    final resolutionRate = totalShortages > 0 ? resolvedShortages / totalShortages : 1.0;
    final resolutionScore = (resolutionRate * 40).round();

    // Critical penalty: 0-30 points lost
    final criticalRatio = totalShortages > 0 ? criticalShortages / totalShortages : 0.0;
    final criticalPenalty = (criticalRatio * 30).round();

    // Activity score: 0-30 points
    final activityScore = totalSubmissions > 10 ? 30 : (totalSubmissions / 10 * 30).round();

    return (resolutionScore + activityScore - criticalPenalty).clamp(0, 100);
  }

  // ─── Insights Generation ──────────────────────────────────────────────────

  /// Generate Arabic text insights from analytics data.
  static List<String> generateInsights(Map<String, dynamic> data) {
    final insights = <String>[];
    final submissions = data['submissions'] as Map<String, dynamic>? ?? {};
    final shortages = data['shortages'] as Map<String, dynamic>? ?? {};

    final total = submissions['total'] as int? ?? 0;
    final today = submissions['today'] as int? ?? 0;
    final totalShortages = shortages['total'] as int? ?? 0;
    final resolved = shortages['resolved'] as int? ?? 0;
    final bySeverity = shortages['bySeverity'] as Map<String, dynamic>? ?? {};
    final critical = bySeverity['critical'] as int? ?? 0;
    final byStatus = submissions['byStatus'] as Map<String, dynamic>? ?? {};
    final rejected = byStatus['rejected'] as int? ?? 0;

    // Health score
    final score = healthScore(
      totalShortages: totalShortages,
      resolvedShortages: resolved,
      criticalShortages: critical,
      totalSubmissions: total,
    );

    if (score >= 80) {
      insights.add('✅ أداء ممتاز! نسبة الإنجاز $score%');
    } else if (score >= 50) {
      insights.add('⚠️ أداء متوسط ($score%) — يحتاج تحسين');
    } else {
      insights.add('🚨 أداء ضعيف ($score%) — تدخل عاجل مطلوب');
    }

    // Today's activity
    if (today == 0 && total > 0) {
      insights.add('📋 لا توجد إرساليات اليوم — قد يشير إلى انخفاض النشاط');
    } else if (today > 0) {
      insights.add('📊 تم إرسال $today نموذج اليوم');
    }

    // Critical shortages
    if (critical > 0) {
      insights.add('🔴 يوجد $critical نقص حرج يحتاج معالجة فورية');
    }

    // Rejection rate
    if (total > 0 && rejected > 0) {
      final rejectRate = (rejected / total * 100).toStringAsFixed(1);
      insights.add('❌ نسبة الرفض $rejectRate% — راجع جودة الإدخال');
    }

    // Resolution rate
    if (totalShortages > 0) {
      final rate = (resolved / totalShortages * 100).toStringAsFixed(0);
      insights.add('✅ تم حل $resolved من $totalShortages نقص ($rate%)');
    }

    return insights;
  }
}
