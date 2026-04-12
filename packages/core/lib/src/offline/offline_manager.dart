import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../security/encryption_service.dart';
import '../errors/app_exceptions.dart';

/// Sync result status enum
enum SyncStatus { success, conflict, error, duplicate }

/// Result of a sync attempt
class SyncResult {
  final String offlineId;
  final SyncStatus status;
  final String? errorMessage;
  final Map<String, dynamic>? serverResponse;

  SyncResult.success(this.offlineId, [this.serverResponse])
      : status = SyncStatus.success,
        errorMessage = null;
  SyncResult.conflict(this.offlineId, [this.serverResponse])
      : status = SyncStatus.conflict,
        errorMessage = null;
  SyncResult.error(this.offlineId, this.errorMessage)
      : status = SyncStatus.error,
        serverResponse = null;
  SyncResult.duplicate(this.offlineId, [this.serverResponse])
      : status = SyncStatus.duplicate,
        errorMessage = null;

  bool get isSuccess => status == SyncStatus.success;
  bool get isConflict => status == SyncStatus.conflict;
  bool get isError => status == SyncStatus.error;
  bool get isDuplicate => status == SyncStatus.duplicate;

  @override
  String toString() => 'SyncResult($offlineId: $status${errorMessage != null ? ' - $errorMessage' : ''})';
}

/// Manages offline data storage, sync queue, drafts, and cache.
/// Handles conflict resolution and retry logic for reliable offline-first operation.
class OfflineManager {
  static const String _boxName = 'epi_offline';
  static const String _syncQueueKey = 'sync_queue';
  static const String _draftsKey = 'drafts';
  static const String _cacheKey = 'cache';
  static const String _conflictsKey = 'sync_conflicts';

  static const int _maxRetries = 3;
  static const int _maxPayloadSize = 1024 * 1024; // 1MB

  late Box<String> _box;
  final EncryptionService _encryption;
  final Connectivity _connectivity = Connectivity();
  final _connectivityController = StreamController<bool>.broadcast();
  final _uuid = const Uuid();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get connectivityStream => _connectivityController.stream;

  OfflineManager(this._encryption);

  Future<void> init() async {
    try {
      await Hive.initFlutter();
    } catch (e) {
      if (kDebugMode) print('Hive.initFlutter failed, using default: $e');
    }
    _box = await Hive.openBox<String>(_boxName);

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      final resultList = results is List<ConnectivityResult> ? results : [results as ConnectivityResult];
      _isOnline = resultList.isNotEmpty &&
          resultList.any((r) => r != ConnectivityResult.none);
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
      }
    });

    // Initial check
    try {
      final results = await _connectivity.checkConnectivity();
      final resultList = results is List<ConnectivityResult> ? results : [results as ConnectivityResult];
      _isOnline = resultList.isNotEmpty &&
          resultList.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      _isOnline = true;
    }
  }

  // ===== SUBMISSIONS QUEUE =====

  /// Add a submission to the offline sync queue with a unique idempotency key.
  Future<String> addToSyncQueue(Map<String, dynamic> submission) async {
    final offlineId = _uuid.v4();
    submission['offline_id'] = offlineId;
    submission['idempotency_key'] = offlineId; // Idempotency key = offline_id
    submission['created_at'] = DateTime.now().toIso8601String();
    submission['retry_count'] = 0;

    // Validate payload size
    final payloadSize = jsonEncode(submission).length;
    if (payloadSize > _maxPayloadSize) {
      throw ValidationException('Submission payload too large (${payloadSize ~/ 1024}KB, max ${_maxPayloadSize ~/ 1024}KB)',
          fieldErrors: {'size': 'exceeds 1MB limit'});
    }

    final queue = _getQueue();
    queue.add(submission);
    await _saveQueue(queue);

    return offlineId;
  }

  List<Map<String, dynamic>> _getQueue() {
    final data = _box.get(_syncQueueKey);
    if (data == null || data.isEmpty) return [];
    try {
      final decoded = jsonDecode(_encryption.decrypt(data));
      return List<Map<String, dynamic>>.from(decoded);
    } catch (e) {
      _box.delete(_syncQueueKey);
      return [];
    }
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final encrypted = _encryption.encrypt(jsonEncode(queue));
    await _box.put(_syncQueueKey, encrypted);
  }

  Future<List<Map<String, dynamic>>> getPendingItems() async {
    return _getQueue();
  }

  Future<void> removeFromQueue(String offlineId) async {
    final queue = _getQueue();
    queue.removeWhere((item) => item['offline_id'] == offlineId);
    await _saveQueue(queue);
  }

  Future<void> clearQueue() async {
    await _box.delete(_syncQueueKey);
  }

  int get pendingCount => _getQueue().length;

  /// Sync all pending items with retry logic and conflict handling.
  /// Returns a list of sync results for each item.
  Future<List<SyncResult>> syncPendingItems(Future<Map<String, dynamic>> Function(Map<String, dynamic>) submitFn) async {
    final pending = _getQueue();
    final results = <SyncResult>[];
    final remaining = <Map<String, dynamic>>[];

    for (final item in pending) {
      try {
        // Add sync metadata
        final payload = Map<String, dynamic>.from(item);
        payload['sync_metadata'] = {
          'client_timestamp': DateTime.now().toIso8601String(),
          'app_version': AppConfig.appVersion,
          'retry_count': item['retry_count'] ?? 0,
        };

        final response = await submitFn(payload);

        // Handle server response
        if (response['status'] == 'duplicate') {
          await removeFromQueue(item['offline_id']);
          results.add(SyncResult.duplicate(item['offline_id'], response));
        } else if (response['conflict'] == true) {
          await _saveConflict(item, response);
          await removeFromQueue(item['offline_id']);
          results.add(SyncResult.conflict(item['offline_id'], response));
        } else if (response['success'] == true) {
          await removeFromQueue(item['offline_id']);
          results.add(SyncResult.success(item['offline_id'], response));
        } else {
          // Unexpected response — treat as error
          results.add(SyncResult.error(item['offline_id'], 'Unexpected server response'));
          remaining.add(item);
        }
      } on ApiException catch (e) {
        final retryCount = (item['retry_count'] ?? 0) as int;
        if (_isRetryableError(e) && retryCount < _maxRetries) {
          item['retry_count'] = retryCount + 1;
          item['last_retry_at'] = DateTime.now().toIso8601String();
          remaining.add(item);
          results.add(SyncResult.error(item['offline_id'], 'RETRY_${retryCount + 1}/${_maxRetries}: ${e.message}'));
        } else {
          await _logSyncError(item, e);
          results.add(SyncResult.error(item['offline_id'], e.message));
          // Don't re-add items that have exceeded retries — they stay in the queue for manual review
          remaining.add(item);
        }
      } catch (e) {
        await _logSyncError(item, e);
        results.add(SyncResult.error(item['offline_id'], e.toString()));
        remaining.add(item);
      }
    }

    // Update queue with remaining items (failed/retryable)
    if (remaining.isNotEmpty) {
      await _saveQueue(remaining);
    }

    _logSyncSummary(results);
    return results;
  }

  /// Check if an error is worth retrying
  bool _isRetryableError(ApiException e) {
    final code = e.code;
    if (code == null) return true; // Unknown errors are retryable
    // Server errors (5xx), network issues, timeouts
    return code.startsWith('5') ||
        code == 'NETWORK' ||
        code == 'timeout' ||
        code == 'ETIMEDOUT' ||
        code == 'ECONNREFUSED';
  }

  // ===== CONFLICTS =====

  Future<void> _saveConflict(Map<String, dynamic> local, Map<String, dynamic> server) async {
    try {
      final conflicts = _getConflicts();
      conflicts[local['offline_id']] = {
        'local': local,
        'server': server,
        'detected_at': DateTime.now().toIso8601String(),
        'resolved': false,
      };
      final encrypted = _encryption.encrypt(jsonEncode(conflicts));
      await _box.put(_conflictsKey, encrypted);
    } catch (e) {
      if (kDebugMode) print('Failed to save conflict: $e');
    }
  }

  Map<String, dynamic> _getConflicts() {
    final data = _box.get(_conflictsKey);
    if (data == null || data.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(data)));
    } catch (_) {
      return {};
    }
  }

  List<Map<String, dynamic>> getUnresolvedConflicts() {
    final conflicts = _getConflicts();
    return conflicts.entries
        .where((e) => e.value['resolved'] != true)
        .map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)})
        .toList();
  }

  Future<void> resolveConflict(String offlineId, {bool useLocal = false}) async {
    final conflicts = _getConflicts();
    if (conflicts.containsKey(offlineId)) {
      conflicts[offlineId]['resolved'] = true;
      conflicts[offlineId]['resolution'] = useLocal ? 'local_wins' : 'server_wins';
      conflicts[offlineId]['resolved_at'] = DateTime.now().toIso8601String();
      final encrypted = _encryption.encrypt(jsonEncode(conflicts));
      await _box.put(_conflictsKey, encrypted);
    }
  }

  Future<void> _logSyncError(Map<String, dynamic> item, dynamic error) async {
    if (kDebugMode) {
      print('Sync error for ${item['offline_id']}: $error');
    }
  }

  void _logSyncSummary(List<SyncResult> results) {
    if (kDebugMode && results.isNotEmpty) {
      final success = results.where((r) => r.isSuccess).length;
      final duplicates = results.where((r) => r.isDuplicate).length;
      final conflicts = results.where((r) => r.isConflict).length;
      final errors = results.where((r) => r.isError).length;
      print('Sync summary: $success ok, $duplicates dup, $conflicts conflict, $errors error');
    }
  }

  // ===== DRAFTS =====

  Future<void> saveDraft(String formId, Map<String, dynamic> data) async {
    final drafts = _getDrafts();
    drafts[formId] = {
      'data': data,
      'saved_at': DateTime.now().toIso8601String(),
    };
    final encrypted = _encryption.encrypt(jsonEncode(drafts));
    await _box.put(_draftsKey, encrypted);
  }

  Map<String, dynamic> _getDrafts() {
    final data = _box.get(_draftsKey);
    if (data == null || data.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(data)));
    } catch (e) {
      _box.delete(_draftsKey);
      return {};
    }
  }

  Map<String, dynamic>? getDraft(String formId) {
    final drafts = _getDrafts();
    return drafts[formId];
  }

  Future<void> removeDraft(String formId) async {
    final drafts = _getDrafts();
    drafts.remove(formId);
    final encrypted = _encryption.encrypt(jsonEncode(drafts));
    await _box.put(_draftsKey, encrypted);
  }

  // ===== CACHE =====

  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    final cache = _getCache();
    cache[key] = {
      'data': data,
      'cached_at': DateTime.now().toIso8601String(),
    };
    await _box.put(_cacheKey, jsonEncode(cache));
  }

  Map<String, dynamic> _getCache() {
    final data = _box.get(_cacheKey);
    if (data == null || data.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic>? getCachedData(String key) {
    final cache = _getCache();
    final entry = cache[key];
    if (entry == null) return null;

    final cachedAt = DateTime.tryParse(entry['cached_at'] ?? '');
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) > AppConfig.cacheExpiry) {
      return null;
    }

    return entry['data'];
  }

  Future<void> clearCache() async {
    await _box.delete(_cacheKey);
  }

  void dispose() {
    _connectivityController.close();
  }
}
