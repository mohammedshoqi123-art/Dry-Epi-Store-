import 'dart:async';
import '../api/api_client.dart';
import '../config/supabase_config.dart';

/// Analytics service that aggregates KPI data from Supabase.
/// Falls back to Edge Function for complex aggregations.
class AnalyticsService {
  final ApiClient _api;

  AnalyticsService(this._api);

  // ─── Dashboard Analytics ──────────────────────────────────────────────────

  /// Main dashboard analytics — submissions + shortages overview
  Future<Map<String, dynamic>> getAnalytics({
    String? governorateId,
    String? districtId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Try Edge Function first for complex aggregation
      final result = await _api.callFunction(SupabaseConfig.fnGetAnalytics, {
        'governorate_id': governorateId,
        'district_id': districtId,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      });
      return result;
    } catch (_) {
      // Fallback: compute locally from raw queries
      return _computeLocalAnalytics(
        governorateId: governorateId,
        districtId: districtId,
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  Future<Map<String, dynamic>> _computeLocalAnalytics({
    String? governorateId,
    String? districtId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final filters = <String, dynamic>{};
    if (governorateId != null) filters['governorate_id'] = governorateId;
    if (districtId != null) filters['district_id'] = districtId;

    // Submissions
    final submissions = await _api.select(
      'form_submissions',
      select: 'id, status, created_at, governorate_id, district_id',
      filters: filters,
      limit: 1000,
    );

    // Shortages
    final shortages = await _api.select(
      'supply_shortages',
      select: 'id, severity, is_resolved, created_at',
      filters: filters.isEmpty ? {} : filters,
      limit: 1000,
    );

    // Compute status distribution
    final byStatus = <String, int>{};
    for (final s in submissions) {
      final status = s['status'] as String? ?? 'unknown';
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }

    // Compute severity distribution
    final bySeverity = <String, int>{};
    for (final s in shortages) {
      final sev = s['severity'] as String? ?? 'unknown';
      bySeverity[sev] = (bySeverity[sev] ?? 0) + 1;
    }

    final resolvedCount = shortages.where((s) => s['is_resolved'] == true).length;

    // Submissions by day (last 7 days)
    final byDay = _groupByDay(submissions, 7);

    return {
      'submissions': {
        'total': submissions.length,
        'byStatus': byStatus,
        'byDay': byDay,
        'today': submissions
            .where((s) => _isToday(s['created_at']))
            .length,
      },
      'shortages': {
        'total': shortages.length,
        'resolved': resolvedCount,
        'pending': shortages.length - resolvedCount,
        'bySeverity': bySeverity,
      },
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  // ─── Detailed Analytics ───────────────────────────────────────────────────

  /// Get submission trends for chart (last N days)
  Future<List<Map<String, dynamic>>> getSubmissionTrend({
    int days = 30,
    String? governorateId,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    final filters = <String, dynamic>{};
    if (governorateId != null) filters['governorate_id'] = governorateId;

    final submissions = await _api.select(
      'form_submissions',
      select: 'created_at, status',
      filters: filters,
      limit: 5000,
    );

    // Group by date
    final grouped = <String, int>{};
    for (var i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      grouped[key] = 0;
    }

    for (final s in submissions) {
      final createdAt = DateTime.tryParse(s['created_at'] as String? ?? '');
      if (createdAt == null || createdAt.isBefore(startDate)) continue;
      final key = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
      grouped[key] = (grouped[key] ?? 0) + 1;
    }

    return grouped.entries
        .map((e) => {'date': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  /// Get top governorates by submission count
  Future<List<Map<String, dynamic>>> getGovernorateRanking() async {
    final submissions = await _api.select(
      'form_submissions',
      select: 'governorate_id, governorates(name_ar, name_en)',
      limit: 5000,
    );

    final grouped = <String, Map<String, dynamic>>{};
    for (final s in submissions) {
      final govId = s['governorate_id'] as String?;
      if (govId == null) continue;
      if (!grouped.containsKey(govId)) {
        grouped[govId] = {
          'governorate_id': govId,
          'name_ar': (s['governorates'] as Map?)?['name_ar'] ?? 'غير محدد',
          'count': 0,
        };
      }
      grouped[govId]!['count'] = (grouped[govId]!['count'] as int) + 1;
    }

    return grouped.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Map<String, int> _groupByDay(List<Map<String, dynamic>> items, int days) {
    final result = <String, int>{};
    final now = DateTime.now();

    for (var i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.month}/${date.day}';
      result[key] = 0;
    }

    for (final item in items) {
      final createdAt = DateTime.tryParse(item['created_at'] as String? ?? '');
      if (createdAt == null) continue;
      if (now.difference(createdAt).inDays > days) continue;
      final key = '${createdAt.month}/${createdAt.day}';
      result[key] = (result[key] ?? 0) + 1;
    }

    return result;
  }

  bool _isToday(dynamic dateStr) {
    if (dateStr == null) return false;
    final date = DateTime.tryParse(dateStr.toString());
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}
