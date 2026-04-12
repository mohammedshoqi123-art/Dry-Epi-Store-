import 'dart:async';
import '../api/api_client.dart';
import '../config/supabase_config.dart';
import '../errors/app_exceptions.dart';

/// Gemini AI service for Arabic analytics insights and chat.
class GeminiService {
  final ApiClient _api;
  final List<Map<String, String>> _history = [];
  static const int _maxHistorySize = 20;

  GeminiService(this._api);

  // ─── Chat ─────────────────────────────────────────────────────────────────

  /// Send a chat message to Gemini (via Edge Function for API key security)
  Future<String> chat(
    String message, {
    Map<String, dynamic>? analyticsContext,
    bool clearHistory = false,
  }) async {
    if (clearHistory) _history.clear();

    _history.add({'role': 'user', 'content': message});

    try {
      final response = await _api.callFunction(SupabaseConfig.fnAiChat, {
        'message': message,
        'history': _history.take(_maxHistorySize).toList(),
        'context': analyticsContext,
        'language': 'ar',
      });

      final reply = response['reply'] as String? ??
          response['text'] as String? ??
          'عذراً، لم أتمكن من معالجة طلبك.';

      _history.add({'role': 'assistant', 'content': reply});

      // Trim history to prevent unbounded growth
      if (_history.length > _maxHistorySize) {
        _history.removeRange(0, _history.length - _maxHistorySize);
      }

      return reply;
    } on ApiException catch (e) {
      throw AIException('فشل الاتصال بالمساعد الذكي: ${e.message}');
    }
  }

  /// Generate insights from analytics data in Arabic
  Future<String> generateInsights(Map<String, dynamic> analyticsData) async {
    final prompt = '''
أنت محلل بيانات متخصص في حملات التطعيم. 
حلل البيانات التالية وقدم رؤى وتوصيات مختصرة باللغة العربية:

البيانات:
- إجمالي الإرساليات: ${analyticsData['submissions']?['total'] ?? 0}
- الإرساليات اليوم: ${analyticsData['submissions']?['today'] ?? 0}
- النواقص الإجمالية: ${analyticsData['shortages']?['total'] ?? 0}
- النواقص الحرجة: ${analyticsData['shortages']?['bySeverity']?['critical'] ?? 0}
- النواقص المحلولة: ${analyticsData['shortages']?['resolved'] ?? 0}

قدم:
1. ملخص الوضع الحالي (جملتين)
2. أهم نقاط الاهتمام (3 نقاط)
3. توصية فورية
''';

    return chat(prompt, analyticsContext: analyticsData, clearHistory: true);
  }

  /// Suggest follow-up questions based on the current data context
  Future<List<String>> suggestQuestions(Map<String, dynamic> context) async {
    try {
      final response = await _api.callFunction(SupabaseConfig.fnAiChat, {
        'message': 'اقترح 3 أسئلة تحليلية مفيدة بناءً على بيانات المنصة',
        'context': context,
        'mode': 'suggestions',
        'language': 'ar',
      });

      final suggestions = response['suggestions'] as List?;
      if (suggestions != null) {
        return suggestions.map((s) => s.toString()).toList();
      }
    } catch (_) {}

    // Fallback suggestions
    return [
      'ما هي المحافظات الأكثر نشاطاً في الإرسال؟',
      'ما أكثر النواقص شيوعاً هذا الشهر؟',
      'كيف تقارن إرساليات هذا الأسبوع بالأسبوع الماضي؟',
    ];
  }

  void clearHistory() => _history.clear();

  List<Map<String, String>> get history => List.unmodifiable(_history);
}
