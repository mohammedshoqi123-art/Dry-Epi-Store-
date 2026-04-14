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
    return _api.select('governorates', orderBy: 'name_ar');
  }

  // ===== DISTRICTS =====

  Future<List<Map<String, dynamic>>> getDistricts({String? governorateId}) async {
    final filters = governorateId != null ? {'governorate_id': governorateId} : <String, dynamic>{};
    return _api.select(
      'districts',
      select: '*, governorates(name_ar, name_en)',
      filters: filters,
      orderBy: 'name_ar',
    );
  }

  // ===== FORMS =====

  Future<List<Map<String, dynamic>>> getForms({bool activeOnly = true}) async {
    return _api.select(
      'forms',
      filters: activeOnly ? {'is_active': true} : {},
      orderBy: 'created_at',
      ascending: false,
    );
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
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = false,
  }) async {
    final filters = <String, dynamic>{};
    if (formId != null) filters['form_id'] = formId;
    if (status != null) filters['status'] = status;
    if (governorateId != null) filters['governorate_id'] = governorateId;
    if (districtId != null) filters['district_id'] = districtId;
    if (submittedBy != null) filters['submitted_by'] = submittedBy;

    return _api.select(
      'form_submissions',
      select: '*, forms(title_ar, title_en), profiles!submitted_by(full_name, email)',
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
      select: '*, forms(title_ar, title_en, schema), profiles!submitted_by(full_name, email)',
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
    int? limit,
    int? offset,
  }) async {
    final filters = <String, dynamic>{};
    if (governorateId != null) filters['governorate_id'] = governorateId;
    if (districtId != null) filters['district_id'] = districtId;
    if (severity != null) filters['severity'] = severity;
    if (isResolved != null) filters['is_resolved'] = isResolved;

    return _api.select(
      'supply_shortages',
      select: '*, governorates(name_ar), districts(name_ar), profiles!reported_by(full_name)',
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

  Future<List<Map<String, dynamic>>> getReferences({bool includeInactive = false}) async {
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
  Future<Map<String, dynamic>> getDashboardStats(String userId) async {
    final response = await _api.callFunction('get-dashboard-stats', {
      'user_id': userId,
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
      final client = SupabaseConfig.isConfigured
          ? Supabase.instance.client
          : null;
      if (client == null) return 0;

      final response = await client
          .from('notifications')
          .select('id', { count: 'exact', head: true })
          .eq('is_read', false);

      return response.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ===== APP SETTINGS =====

  /// Get all app settings or a specific one
  Future<Map<String, dynamic>> getAppSettings({String? key}) async {
    if (key != null) {
      final result = await _api.selectOne('app_settings', filters: {'key': key});
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
