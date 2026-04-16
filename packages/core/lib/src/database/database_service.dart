import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../api/api_client.dart';

class DatabaseService {
  final ApiClient _api;

  DatabaseService(this._api);

  // ===== PROFILES =====

  Future<List<Map<String, dynamic>>> getUsers({
    String? role,
    String? governorateId,
    String? districtId,
    int? limit,
    int? offset,
  }) async {
    final filters = <String, dynamic>{};
    if (role != null) filters['role'] = role;
    if (governorateId != null) filters['governorate_id'] = governorateId;
    if (districtId != null) filters['district_id'] = districtId;

    return _api.select(
      'profiles',
      select: '*, governorates(name_ar, name_en), districts(name_ar, name_en)',
      filters: filters,
      orderBy: 'created_at',
      ascending: false,
      limit: limit,
      offset: offset,
    );
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return _api.selectOne(
      'profiles',
      select: '*, governorates(name_ar, name_en), districts(name_ar, name_en)',
      filters: {'id': userId},
    );
  }

  Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    return _api.update('profiles', data, filters: {'id': userId});
  }

  // ===== GOVERNORATES =====

  Future<List<Map<String, dynamic>>> getGovernorates() async {
    return _api.select(
      'governorates',
      filters: {'deleted_at': ApiClient.isNull, 'is_active': true},
      orderBy: 'name_ar',
    );
  }

  // ===== DISTRICTS =====

  Future<List<Map<String, dynamic>>> getDistricts(
      {String? governorateId}) async {
    final filters = <String, dynamic>{
      'deleted_at': ApiClient.isNull,
      'is_active': true,
    };
    if (governorateId != null) filters['governorate_id'] = governorateId;
    return _api.select(
      'districts',
      select: '*, governorates(name_ar, name_en)',
      filters: filters,
      orderBy: 'name_ar',
    );
  }

  // ===== HEALTH FACILITIES =====

  Future<List<Map<String, dynamic>>> getHealthFacilities(
      {String? districtId}) async {
    final filters = <String, dynamic>{
      'deleted_at': ApiClient.isNull,
      'is_active': true,
    };
    if (districtId != null) filters['district_id'] = districtId;
    return _api.select(
      'health_facilities',
      filters: filters,
      orderBy: 'name_ar',
    );
  }

  // ===== FORMS =====

  Future<List<Map<String, dynamic>>> getForms(
      {bool activeOnly = true, String? campaignType}) async {
    final filters = <String, dynamic>{
      'deleted_at': ApiClient.isNull, // exclude soft-deleted forms
    };
    if (activeOnly) filters['is_active'] = true;
    if (campaignType != null) filters['campaign_type'] = campaignType;
    return _api.select(
      'forms',
      filters: filters,
      orderBy: 'created_at',
      ascending: false,
    );
  }

  /// Get the current user's active campaign from their profile.
  Future<String> getActiveCampaign() async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return 'polio_campaign';
      final profile = await _api.selectOne('profiles', filters: {'id': userId});
      return profile['active_campaign'] as String? ?? 'polio_campaign';
    } catch (_) {
      return 'polio_campaign';
    }
  }

  /// Set the current user's active campaign.
  Future<void> setActiveCampaign(String campaign) async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return;
    await _api.update('profiles', {'active_campaign': campaign},
        filters: {'id': userId});
  }

  Future<Map<String, dynamic>> getForm(String formId) async {
    return _api.selectOne('forms', filters: {'id': formId});
  }

  Future<Map<String, dynamic>> createForm(Map<String, dynamic> data) async {
    return _api.insert('forms', data);
  }

  Future<Map<String, dynamic>> updateForm(
    String formId,
    Map<String, dynamic> data,
  ) async {
    return _api.update('forms', data, filters: {'id': formId});
  }

  // ===== SUBMISSIONS =====

  Future<List<Map<String, dynamic>>> getSubmissions({
    String? formId,
    String? status,
    String? governorateId,
    String? districtId,
    String? submittedBy,
    String? campaignType,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = false,
  }) async {
    // ═══ FIX: Resolve campaign form IDs first, then filter server-side ═══
    if (campaignType != null && formId == null) {
      final campaignForms = await getForms(campaignType: campaignType);
      if (campaignForms.isEmpty) return []; // No forms for this campaign
      final formIds = campaignForms.map((f) => f['id'] as String).toList();

      // Build filters including form_id IN list via multiple queries combined
      // Since ApiClient.select only supports .eq, fetch each form's submissions
      // and merge results, then sort + paginate
      final allResults = <Map<String, dynamic>>[];
      for (final fid in formIds) {
        final filters = <String, dynamic>{'form_id': fid};
        if (status != null) filters['status'] = status;
        if (governorateId != null) filters['governorate_id'] = governorateId;
        if (districtId != null) filters['district_id'] = districtId;
        if (submittedBy != null) filters['submitted_by'] = submittedBy;

        final results = await _api.select(
          'form_submissions',
          select:
              '*, forms!form_id(title_ar, title_en, campaign_type), profiles!submitted_by(full_name, email)',
          filters: filters,
          orderBy: orderBy ?? 'created_at',
          ascending: ascending,
          limit: limit,
          offset: offset,
        );
        allResults.addAll(results);
      }

      // Sort merged results by the requested order
      final sortKey = orderBy ?? 'created_at';
      allResults.sort((a, b) {
        final aVal = a[sortKey]?.toString() ?? '';
        final bVal = b[sortKey]?.toString() ?? '';
        return ascending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
      });

      // Apply final limit
      if (limit != null && allResults.length > limit) {
        return allResults.sublist(0, limit);
      }
      return allResults;
    }

    final filters = <String, dynamic>{};
    if (formId != null) filters['form_id'] = formId;
    if (status != null) filters['status'] = status;
    if (governorateId != null) filters['governorate_id'] = governorateId;
    if (districtId != null) filters['district_id'] = districtId;
    if (submittedBy != null) filters['submitted_by'] = submittedBy;

    return _api.select(
      'form_submissions',
      select:
          '*, forms!form_id(title_ar, title_en, campaign_type), profiles!submitted_by(full_name, email)',
      filters: filters,
      orderBy: orderBy ?? 'created_at',
      ascending: ascending,
      limit: limit,
      offset: offset,
    );
  }

  Future<Map<String, dynamic>> getSubmission(String id) async {
    return _api.selectOne(
      'form_submissions',
      select:
          '*, forms(title_ar, title_en, schema), profiles!submitted_by(full_name, email)',
      filters: {'id': id},
    );
  }

  Future<Map<String, dynamic>> submitForm(Map<String, dynamic> data) async {
    return _api.callFunction(SupabaseConfig.fnSubmitForm, data);
  }

  Future<Map<String, dynamic>> updateSubmissionStatus(
    String id,
    String status, {
    String? reviewNotes,
    String? reviewedBy,
  }) async {
    final data = {
      'status': status,
      'reviewed_at': DateTime.now().toIso8601String(),
      if (reviewNotes != null) 'review_notes': reviewNotes,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
    };
    return _api.update('form_submissions', data, filters: {'id': id});
  }

  // ===== SUPPLY SHORTAGES =====

  Future<List<Map<String, dynamic>>> getShortages({
    String? governorateId,
    String? districtId,
    String? severity,
    bool? isResolved,
    String? campaignType,
    int? limit,
    int? offset,
  }) async {
    // ═══ FIX: Filter shortages by campaign via resolved form IDs — server-side per form ═══
    if (campaignType != null) {
      final campaignForms = await getForms(campaignType: campaignType);
      if (campaignForms.isEmpty) return [];
      final formIds = campaignForms.map((f) => f['id'] as String).toList();

      // Get submission IDs for these forms (limited scan)
      final submissions = await _api.select(
        'form_submissions',
        select: 'id, form_id',
        filters: {},
        limit: 5000,
      );
      final submissionIds = submissions
          .where((s) => formIds.contains(s['form_id']))
          .map((s) => s['id'] as String)
          .toSet();

      if (submissionIds.isEmpty) return [];

      // Fetch shortages and filter by submission_id match
      final baseFilters = <String, dynamic>{};
      if (governorateId != null) baseFilters['governorate_id'] = governorateId;
      if (districtId != null) baseFilters['district_id'] = districtId;
      if (severity != null) baseFilters['severity'] = severity;
      if (isResolved != null) baseFilters['is_resolved'] = isResolved;

      final allShortages = await _api.select(
        'supply_shortages',
        select:
            '*, governorates(name_ar), districts(name_ar), profiles!reported_by(full_name)',
        filters: baseFilters,
        orderBy: 'created_at',
        ascending: false,
        limit: limit ?? 50,
        offset: offset,
      );

      // Filter: keep shortages whose submission_id matches campaign forms, or shortages without submission_id
      var filtered = allShortages.where((s) {
        final subId = s['submission_id'] as String?;
        return subId == null || submissionIds.contains(subId);
      }).toList();

      if (limit != null && filtered.length > limit) {
        filtered = filtered.sublist(0, limit);
      }
      return filtered;
    }

    final filters = <String, dynamic>{};
    if (governorateId != null) filters['governorate_id'] = governorateId;
    if (districtId != null) filters['district_id'] = districtId;
    if (severity != null) filters['severity'] = severity;
    if (isResolved != null) filters['is_resolved'] = isResolved;

    return _api.select(
      'supply_shortages',
      select:
          '*, governorates(name_ar), districts(name_ar), profiles!reported_by(full_name)',
      filters: filters,
      orderBy: 'created_at',
      ascending: false,
      limit: limit,
      offset: offset,
    );
  }

  // ===== AUDIT LOGS =====

  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? userId,
    String? action,
    String? tableName,
    int? limit,
    int? offset,
  }) async {
    final filters = <String, dynamic>{};
    if (userId != null) filters['user_id'] = userId;
    if (action != null) filters['action'] = action;
    if (tableName != null) filters['table_name'] = tableName;

    return _api.select(
      'audit_logs',
      select: '*, profiles(full_name, email)',
      filters: filters,
      orderBy: 'created_at',
      ascending: false,
      limit: limit ?? 50,
      offset: offset,
    );
  }

  // ===== REFERENCES =====

  Future<List<Map<String, dynamic>>> getReferences(
      {bool includeInactive = false}) async {
    final filters = <String, dynamic>{};
    if (!includeInactive) filters['is_active'] = true;
    return _api.select(
      'doc_references',
      filters: filters,
      orderBy: 'created_at',
      ascending: false,
    );
  }

  Future<void> createReference(Map<String, dynamic> data) async {
    await _api.insert('doc_references', data);
  }

  Future<void> updateReference(String id, Map<String, dynamic> data) async {
    await _api.update('doc_references', data, filters: {'id': id});
  }

  // ===== DASHBOARD =====

  /// Get dashboard stats for the current user (role-based)
  Future<Map<String, dynamic>> getDashboardStats(String userId,
      {String? campaignType}) async {
    final response = await _api.callFunction('get-dashboard-stats', {
      'user_id': userId,
      if (campaignType != null) 'campaign_type': campaignType,
    });
    return response;
  }

  // ===== REPORTS =====

  /// Get governorate report with submission breakdown
  Future<List<Map<String, dynamic>>> getGovernorateReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;

    final response = await _api.callFunction('get-governorate-report', {
      'start_date': start.toIso8601String().split('T').first,
      'end_date': end.toIso8601String().split('T').first,
    });

    // callFunction wraps List responses in {"data": [...]}
    final rawData = response['data'] ?? response;
    if (rawData is List) {
      return List<Map<String, dynamic>>.from(rawData);
    }
    return [];
  }

  // ===== NOTIFICATIONS =====

  /// Get user notifications (paginated)
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final filters = <String, dynamic>{};
    if (unreadOnly) filters['is_read'] = false;

    return _api.select(
      'notifications',
      filters: filters,
      orderBy: 'created_at',
      ascending: false,
      limit: limit,
      offset: offset,
    );
  }

  /// Get unread notification count using efficient count query
  Future<int> getUnreadNotificationCount() async {
    try {
      final result = await _api.selectOne(
        'notifications',
        select: 'count',
        filters: {'is_read': false},
      );
      // Supabase returns count in the response when using count select
      final count = result['count'];
      if (count is int) return count;
      if (count is String) return int.tryParse(count) ?? 0;
      // Fallback: count results from limited select
      final results = await _api.select(
        'notifications',
        select: 'id',
        filters: {'is_read': false},
        limit: 100,
      );
      return results.length;
    } catch (_) {
      return 0;
    }
  }

  // ===== APP SETTINGS =====

  /// Get all app settings or a specific one
  Future<Map<String, dynamic>> getAppSettings({String? key}) async {
    if (key != null) {
      final result =
          await _api.selectOne('app_settings', filters: {'key': key});
      return result;
    }
    final results = await _api.select('app_settings');
    return {for (var r in results) r['key']: r['value']};
  }

  /// Update an app setting
  Future<void> updateAppSetting(String key, dynamic value) async {
    await _api.update(
      'app_settings',
      {'value': value, 'updated_at': DateTime.now().toIso8601String()},
      filters: {'key': key},
    );
  }
}
