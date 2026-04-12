import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../security/encryption_service.dart';

/// Unified local data repository for full offline-first operation.
/// Stores forms, submissions, and computes analytics locally.
class LocalRepository {
  static const _formsBox = 'local_forms';
  static const _subsBox = 'local_submissions';
  static const _settingsBox = 'local_settings';

  final EncryptionService _enc;

  LocalRepository(this._enc);

  Future<void> init() async {
    await Hive.openBox<String>(_formsBox);
    await Hive.openBox<String>(_subsBox);
    await Hive.openBox<String>(_settingsBox);
  }

  // ─── Forms ────────────────────────────────────────────────────────────────

  Future<void> saveForms(List<Map<String, dynamic>> forms) async {
    final box = Hive.box<String>(_formsBox);
    for (final f in forms) {
      await box.put(f['id'], _enc.encrypt(jsonEncode(f)));
    }
  }

  Future<List<Map<String, dynamic>>> getForms({bool activeOnly = true}) async {
    final box = Hive.box<String>(_formsBox);
    return box.values.map((v) {
      try {
        return Map<String, dynamic>.from(jsonDecode(_enc.decrypt(v)));
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((f) {
      if (f.isEmpty) return false;
      return !activeOnly || f['is_active'] == true;
    }).toList();
  }

  // ─── Submissions ──────────────────────────────────────────────────────────

  Future<void> saveSubmission(Map<String, dynamic> sub) async {
    final box = Hive.box<String>(_subsBox);
    final id = sub['offline_id'] ?? sub['id'];
    await box.put(id, _enc.encrypt(jsonEncode(sub)));
  }

  Future<List<Map<String, dynamic>>> getSubmissions() async {
    final box = Hive.box<String>(_subsBox);
    return box.values.map((v) {
      try {
        return Map<String, dynamic>.from(jsonDecode(_enc.decrypt(v)));
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((s) => s.isNotEmpty).toList();
  }

  // ─── Analytics (100% local) ───────────────────────────────────────────────

  /// Compute analytics entirely on-device, no server needed.
  Map<String, dynamic> computeLocalAnalytics() {
    final subs = Hive.box<String>(_subsBox).values.map((v) {
      try {
        return Map<String, dynamic>.from(jsonDecode(_enc.decrypt(v)));
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((s) => s.isNotEmpty).toList();

    final today = DateTime.now().toIso8601String().substring(0, 10);

    final byStatus = <String, int>{};
    for (final s in subs) {
      final status = s['status'] as String? ?? 'unknown';
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }

    return {
      'submissions': {
        'total': subs.length,
        'today': subs.where((s) => (s['created_at'] ?? '').startsWith(today)).length,
        'byStatus': byStatus,
      },
    };
  }

  // ─── Settings ─────────────────────────────────────────────────────────────

  Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box<String>(_settingsBox);
    await box.put(key, jsonEncode(value));
  }

  dynamic getSetting(String key) {
    final box = Hive.box<String>(_settingsBox);
    final val = box.get(key);
    if (val == null) return null;
    try {
      return jsonDecode(val);
    } catch (_) {
      return val;
    }
  }

  // ─── Export / Import (for backup) ─────────────────────────────────────────

  Future<Map<String, dynamic>> exportAll() async {
    return {
      'forms': await getForms(activeOnly: false),
      'submissions': await getSubmissions(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    if (data['forms'] != null) {
      await saveForms(List<Map<String, dynamic>>.from(data['forms']));
    }
    if (data['submissions'] != null) {
      for (final s in List<Map<String, dynamic>>.from(data['submissions'])) {
        await saveSubmission(s);
      }
    }
  }
}
