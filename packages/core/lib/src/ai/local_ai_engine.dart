import '../analytics/local_analytics_engine.dart';

/// Local AI engine for 100% offline chat and analytics.
/// Uses rule-based logic + local analytics — no internet required.
class LocalAIEngine {
  final List<Map<String, String>> _history = [];

  /// Chat entirely on-device, no network needed.
  String chat(String message, {Map<String, dynamic>? data}) {
    _history.add({'role': 'user', 'content': message});

    final response = _processQuery(message, data ?? {});
    _history.add({'role': 'assistant', 'content': response});
    return response;
  }

  String _processQuery(String q, Map<String, dynamic> d) {
    final lower = q.toLowerCase();

    if (_has(lower, ['عدد', 'كم', 'ارساليات'])) return _count(d);
    if (_has(lower, ['نقص', 'نواقص'])) return _shortage(d);
    if (_has(lower, ['توصي', 'توصية'])) return _recommend(d);
    if (_has(lower, ['ملخص', 'ملخص'])) return _summary(d);
    if (_has(lower, ['اتجاه', ' tendência'])) return _trend(d);

    return _generalInsight(d);
  }

  // ─── Query Handlers ───────────────────────────────────────────────────────

  String _count(Map<String, dynamic> d) {
    final subs = d['submissions'] as Map<String, dynamic>? ?? {};
    final t = subs['total'] ?? 0;
    final td = subs['today'] ?? 0;
    return 'إجمالي الإرساليات: $t. اليوم: $td إرسالية.';
  }

  String _shortage(Map<String, dynamic> d) {
    final shorts = d['shortages'] as Map<String, dynamic>? ?? {};
    final t = shorts['total'] ?? 0;
    final bySev = shorts['bySeverity'] as Map<String, dynamic>? ?? {};
    final c = bySev['critical'] ?? 0;
    if (t == 0) return 'لا توجد نواقص مسجلة. ممتاز!';
    return 'يوجد $t نقص منها $c حرج يحتاج معالجة فورية.';
  }

  String _summary(Map<String, dynamic> d) {
    final subs = d['submissions'] as Map<String, dynamic>? ?? {};
    final shorts = d['shortages'] as Map<String, dynamic>? ?? {};
    return 'ملخص: ${subs['total']} إرسالية '
        '${shorts['total']} نقص '
        '${shorts['resolved']} محلول.';
  }

  String _recommend(Map<String, dynamic> d) =>
      LocalAnalyticsEngine.generateInsights(d).join('\n');

  String _trend(Map<String, dynamic> d) => 'تحليل الاتجاه يتطلب بيانات تاريخية أكثر للتحليل.';

  String _generalInsight(Map<String, dynamic> d) =>
      LocalAnalyticsEngine.generateInsights(d).firstOrNull ??
      'مرحباً! كيف يمكنني مساعدتك';

  bool _has(String s, List<String> k) => k.any(s.contains);

  /// Clear conversation history
  void clearHistory() => _history.clear();

  List<Map<String, String>> get history => List.unmodifiable(_history);
}
