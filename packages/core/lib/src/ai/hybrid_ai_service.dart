import '../offline/offline_manager.dart';
import 'gemini_service.dart';
import 'local_ai_engine.dart';

/// Hybrid AI service that falls back gracefully:
/// Online  → Gemini API (full AI)
/// Offline → Local rule-based engine
class HybridAIService {
  final LocalAIEngine _local;
  final GeminiService? _gemini;
  final OfflineManager _offline;

  HybridAIService({
    required LocalAIEngine local,
    GeminiService? gemini,
    required OfflineManager offline,
  })  : _local = local,
        _gemini = gemini,
        _offline = offline;

  /// Send a chat message. Uses Gemini when online, falls back to local engine.
  Future<String> chat(String message, {Map<String, dynamic>? data}) async {
    if (_offline.isOnline && _gemini != null) {
      try {
        return await _gemini!.chat(message, analyticsContext: data);
      } catch (_) {
        // Fallback to local on any Gemini failure
      }
    }
    return _local.chat(message, data: data ?? {});
  }

  /// Human-readable mode label
  String get currentMode =>
      _offline.isOnline ? 'Gemini (متصل)' : 'محلي (بدون إنترنت)';

  /// Whether running fully offline
  bool get isOffline => !_offline.isOnline;

  void clearHistory() {
    _local.clearHistory();
    _gemini?.clearHistory();
  }
}
