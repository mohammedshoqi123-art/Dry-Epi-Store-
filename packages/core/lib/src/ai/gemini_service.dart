import 'dart:async';
import '../api/api_client.dart';
import '../config/supabase_config.dart';
import '../errors/app_exceptions.dart';

/// Gemini/MiMo AI service — token-optimized with templates and modes.
class GeminiService {
  final ApiClient _api;
  final List<Map<String, String>> _history = [];
  // ═══ FIX: Reduced from 20 to 6 (3 turns) to save tokens ═══
  static const int _maxHistorySize = 6;

  GeminiService(this._api);

  // ─── Chat ─────────────────────────────────────────────────────────────────

  /// Send a message. Pass [mode] for special behaviors, [template] for report generation.
  Future<String> chat(
    String message, {
    Map<String, dynamic>? analyticsContext,
    String? mode,
    String? template,
    bool clearHistory = false,
  }) async {
    if (clearHistory) _history.clear();

    _history.add({'role': 'user', 'content': message});

    try {
      final body = <String, dynamic>{
        'message': message,
        'history': _history.take(_maxHistorySize).toList(),
        'language': 'ar',
      };
      if (analyticsContext != null) body['context'] = analyticsContext;
      if (mode != null) body['mode'] = mode;
      if (template != null) body['template'] = template;

      final response = await _api.callFunction(SupabaseConfig.fnAiChat, body);

      final reply = response['reply'] as String? ??
          response['text'] as String? ??
          'عذراً، لم أتمكن من معالجة طلبك.';

      _history.add({'role': 'assistant', 'content': reply});

      // Trim history
      if (_history.length > _maxHistorySize) {
        _history.removeRange(0, _history.length - _maxHistorySize);
      }

      return reply;
    } on ApiException catch (e) {
      throw AIException('فشل الاتصال بالمساعد: ${e.message}');
    }
  }

  // ─── Smart Suggestions ────────────────────────────────────────────────────

  /// Get contextual suggestions based on current data
  Future<List<String>> getSuggestions({Map<String, dynamic>? context}) async {
    try {
      final response = await _api.callFunction(SupabaseConfig.fnAiChat, {
        'mode': 'suggestions',
        'context': context,
        'language': 'ar',
      });
      final suggestions = response['suggestions'] as List?;
      if (suggestions != null && suggestions.isNotEmpty) {
        return suggestions.map((s) => s.toString()).toList();
      }
    } catch (_) {}
    return _fallbackSuggestions();
  }

  List<String> _fallbackSuggestions() => [
        '📊 ما حالة الإرساليات اليوم؟',
        '⚠️ أين النواقص الحرجة؟',
        '📈 اعرض تقرير أسبوعي',
        '🗺️ أي المحافظات تحتاج دعم؟',
      ];

  // ─── Report Templates ─────────────────────────────────────────────────────

  /// Get available report templates
  Future<List<Map<String, dynamic>>> getReportTemplates() async {
    try {
      final response = await _api.callFunction(SupabaseConfig.fnAiChat, {
        'mode': 'report_templates',
        'language': 'ar',
      });
      final templates = response['templates'] as List?;
      if (templates != null && templates.isNotEmpty) {
        return templates.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return _fallbackTemplates();
  }

  /// Generate a report using a template
  Future<String> generateReport({
    required String templateId,
    required Map<String, dynamic> analyticsData,
  }) async {
    final descriptions = {
      'daily':
          'أنشئ تقريراً يومياً شاملاً: ملخص الإرساليات، توزيع الحالات، النواقص الحرجة، توصيات.',
      'weekly':
          'حلل اتجاه الأسبوع: هل الإرساليات في تحسن أم تراجع؟ ما الأسباب؟',
      'governorate':
          'قارن أداء المحافظات: الأفضل أداءً، الأضعف، مع نسب وترتيب.',
      'shortages': 'حلل النواقص: حسب الخطورة، حسب الموقع، أولويات المعالجة.',
      'quality':
          'حلل جودة البيانات: نسبة الرفض، اكتمال الحقول، أكثر الأخطاء شيوعاً.',
      'comparison':
          'قارن فترتين زمنيتين: الأسبوع الحالي مقابل السابق، مع نسب التغيير.',
      'coverage':
          'حلل تغطية التطعيم: Penta3، نسبة الانسحاب، حصبة. حدد الفجوات والتدخلات.',
      'field_performance':
          'تقييم أداء المشرفين الميدانيين: عدد الإرساليات، جودة الإدخال، الالتزام.',
    };

    return chat(
      descriptions[templateId] ?? 'أنشئ تقريراً بالبيانات المتاحة.',
      analyticsContext: analyticsData,
      clearHistory: true,
    );
  }

  List<Map<String, dynamic>> _fallbackTemplates() => [
        {
          'id': 'daily',
          'name': 'التقرير اليومي',
          'description': 'ملخص شامل ليوم العمل',
          'icon': '📅'
        },
        {
          'id': 'weekly',
          'name': 'التقرير الأسبوعي',
          'description': 'تحليل اتجاه الأسبوع',
          'icon': '📊'
        },
        {
          'id': 'governorate',
          'name': 'تقرير المحافظات',
          'description': 'مقارنة أداء المحافظات',
          'icon': '🗺️'
        },
        {
          'id': 'shortages',
          'name': 'تقرير النواقص',
          'description': 'تحليل النواقص والحلول',
          'icon': '⚠️'
        },
        {
          'id': 'quality',
          'name': 'تقرير جودة البيانات',
          'description': 'اكتمال ودقة الإدخال',
          'icon': '✅'
        },
        {
          'id': 'comparison',
          'name': 'تقرير مقارنة',
          'description': 'مقارنة فترتين زمنيتين',
          'icon': '🔄'
        },
        {
          'id': 'coverage',
          'name': 'تقرير التغطية',
          'description': 'تغطية التطعيمات وفجوات',
          'icon': '💉'
        },
        {
          'id': 'field_performance',
          'name': 'تقييم الميدانيين',
          'description': 'أداء المشرفين الميدانيين',
          'icon': '👥'
        },
      ];

  // ─── Quick Actions ─────────────────────────────────────────────────────────

  /// Get contextual quick actions based on current data
  Future<List<Map<String, dynamic>>> getQuickActions(
      {Map<String, dynamic>? context}) async {
    try {
      final response = await _api.callFunction(SupabaseConfig.fnAiChat, {
        'mode': 'quick_actions',
        'context': context,
        'language': 'ar',
      });
      final actions = response['actions'] as List?;
      if (actions != null && actions.isNotEmpty) {
        return actions.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [
      {'label': 'تقرير يومي', 'icon': '📅', 'action': 'daily_report'},
      {'label': 'فحص النواقص', 'icon': '⚠️', 'action': 'check_shortages'},
      {
        'label': 'تغطية التطعيم',
        'icon': '💉',
        'action': 'vaccination_coverage'
      },
    ];
  }

  // ─── Quick Analysis ───────────────────────────────────────────────────────

  /// Quick one-shot analysis — no history, minimal tokens
  Future<String> quickAnalysis(String question, Map<String, dynamic> data) {
    return chat(question, analyticsContext: data, clearHistory: true);
  }

  // ─── Usage Guide ──────────────────────────────────────────────────────────

  /// Ask about how to use a feature
  Future<String> askGuide(String feature) {
    return chat(
      'اشرح لي كيفية $feature في منصة مشرف EPI',
      clearHistory: true,
    );
  }

  void clearHistory() => _history.clear();
  List<Map<String, String>> get history => List.unmodifiable(_history);
}
