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
enum OfflineSyncStatus { success, conflict, error, duplicate }

/// Result of a sync attempt
class OfflineSyncResult {
  final String offlineId;
  final OfflineSyncStatus status;
  final String? errorMessage;
  final Map<String, dynamic>? serverResponse;

  OfflineSyncResult.success(this.offlineId, [this.serverResponse])
      : status = OfflineSyncStatus.success,
        errorMessage = null;
  OfflineSyncResult.conflict(this.offlineId, [this.serverResponse])
      : status = OfflineSyncStatus.conflict,
        errorMessage = null;
  OfflineSyncResult.error(this.offlineId, this.errorMessage)
      : status = OfflineSyncStatus.error,
        serverResponse = null;
  OfflineSyncResult.duplicate(this.offlineId, [this.serverResponse])
      : status = OfflineSyncStatus.duplicate,
        errorMessage = null;

  bool get isSuccess => status == OfflineSyncStatus.success;
  bool get isConflict => status == OfflineSyncStatus.conflict;
  bool get isError => status == OfflineSyncStatus.error;
  bool get isDuplicate => status == OfflineSyncStatus.duplicate;

  @override
  String toString() => 'OfflineSyncResult($offlineId: $status${errorMessage != null ? ' - $errorMessage' : ''})';
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

  Box<String>? _box;
  final EncryptionService _encryption;
  final _connectivityController = StreamController<bool>.broadcast();
  final _uuid = const Uuid();

  bool _initialized = false;

  // ═══ FIX: Use late-initialized connectivity status, default to true ═══
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Update connectivity status from external source (ConnectivityUtils).
  void updateConnectivity(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      if (!_connectivityController.isClosed) {
        _connectivityController.add(_isOnline);
      }
      if (kDebugMode) print('[OfflineManager] Connectivity changed: ${online ? "online" : "offline"}');
    }
  }

  /// Whether the offline storage is initialized and ready
  bool get isInitialized => _box != null && _box!.isOpen;

  OfflineManager(this._encryption);

  Future<void> init() async {
    if (_initialized) {
      if (kDebugMode) print('[OfflineManager] Already initialized, skipping');
      return;
    }

    try {
      try {
        _box = await Hive.openBox<String>(_boxName).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Hive box open timed out');
          },
        );
      } catch (_) {
        await Hive.initFlutter().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (kDebugMode) print('Hive.initFlutter timed out');
            throw TimeoutException('Hive initialization timed out');
          },
        );
        _box = await Hive.openBox<String>(_boxName).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Hive box open timed out after init');
          },
        );
      }
    } catch (e) {
      if (kDebugMode) print('[OfflineManager] Init failed: $e');
      rethrow;
    }

    // ═══ FIX: Recover stuck items from previous crashes ═══
    await _recoverStuckSyncingItems();

    _initialized = true;
    if (kDebugMode) print('[OfflineManager] Initialized. Pending items: ${_getQueue().length}');
  }

  // ═══ FIX: Serialize write operations to prevent race conditions ═══
  final _lockQueue = <Completer<void>>[];

  Future<T> _withWriteLock<T>(Future<T> Function() action) async {
    final prevLock = _lockQueue.isNotEmpty ? _lockQueue.last : null;
    final myLock = Completer<void>();
    _lockQueue.add(myLock);

    if (prevLock != null) {
      await prevLock.future;
    }

    try {
      return await action();
    } finally {
      myLock.complete();
      _lockQueue.remove(myLock);
    }
  }

  // ═══ FIX: Recover items stuck in "syncing" state from previous crashes/restarts ═══
  Future<void> _recoverStuckSyncingItems() async {
    if (_box == null || !_box!.isOpen) return;

    final data = _safeBox.get(_syncQueueKey);
    if (data == null || data.isEmpty) return;

    try {
      final decoded = jsonDecode(_encryption.decrypt(data));
      final queue = List<Map<String, dynamic>>.from(decoded);

      int recovered = 0;
      for (int i = 0; i < queue.length; i++) {
        final item = queue[i];
        if (item['_syncing'] == true) {
          // Reset stuck items: remove the _syncing flag, reset retry count
          // so they get picked up on next sync attempt
          queue[i] = Map<String, dynamic>.from(item);
          queue[i].remove('_syncing');
          queue[i]['retry_count'] = (item['retry_count'] ?? 0);
          queue[i]['_recovered'] = true;
          recovered++;
        }
      }

      if (recovered > 0) {
        final encrypted = _encryption.encrypt(jsonEncode(queue));
        await _safeBox.put(_syncQueueKey, encrypted);
        if (kDebugMode) print('[OfflineManager] Recovered $recovered stuck syncing items');
      }
    } catch (e) {
      if (kDebugMode) print('[OfflineManager] Recovery check failed: $e');
    }
  }

  // ===== SUBMISSIONS QUEUE =====

  /// Add a submission to the offline sync queue with a unique idempotency key.
  Future<String> addToSyncQueue(Map<String, dynamic> submission) async {
    return _withWriteLock(() async {
      final offlineId = _uuid.v4();
      submission['offline_id'] = offlineId;
      submission['idempotency_key'] = offlineId;
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
      _invalidatePendingCount();

      return offlineId;
    });
  }

  /// Safe box access — throws if not initialized
  Box<String> get _safeBox {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('OfflineManager not initialized. Call init() first.');
    }
    return b;
  }

  List<Map<String, dynamic>> _getQueue() {
    final data = _safeBox.get(_syncQueueKey);
    if (data == null || data.isEmpty) return [];
    try {
      final decoded = jsonDecode(_encryption.decrypt(data));
      return List<Map<String, dynamic>>.from(decoded);
    } catch (e) {
      if (kDebugMode) print('[OfflineManager] Queue decrypt error: $e');
      return [];
    }
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final encrypted = _encryption.encrypt(jsonEncode(queue));
    await _safeBox.put(_syncQueueKey, encrypted);
  }

  Future<List<Map<String, dynamic>>> getPendingItems() async {
    return _getQueue();
  }

  Future<void> removeFromQueue(String offlineId) async {
    final queue = _getQueue();
    queue.removeWhere((item) => item['offline_id'] == offlineId);
    await _saveQueue(queue);
    _invalidatePendingCount();
  }

  Future<void> clearQueue() async {
    await _safeBox.delete(_syncQueueKey);
    _invalidatePendingCount();
  }

  // ✅ FIX: Cache pending count to avoid decrypting queue on every access
  int _cachedPendingCount = -1;
  int get pendingCount {
    if (_cachedPendingCount < 0) {
      _cachedPendingCount = _getQueue().length;
    }
    return _cachedPendingCount;
  }

  /// Force recalculate count (call after queue changes)
  void _invalidatePendingCount() {
    _cachedPendingCount = -1;
  }

  /// Sync all pending items with retry logic and conflict handling.
  /// ═══ FIX: Process in-memory, save ONCE at end — prevents data loss on crash ═══
  Future<List<OfflineSyncResult>> syncPendingItems(Future<Map<String, dynamic>> Function(Map<String, dynamic>) submitFn) async {
    final pending = _getQueue();
    if (pending.isEmpty) return [];

    final results = <OfflineSyncResult>[];
    final remaining = <Map<String, dynamic>>[];
    final successfullySynced = <String>[];

    // ═══ FIX: Mark items as _syncing to prevent duplicate processing ═══
    // If we crash during sync, _recoverStuckSyncingItems will reset them on next init
    for (final item in pending) {
      item['_syncing'] = true;
    }

    for (final item in pending) {
      try {
        // Add sync metadata
        final payload = Map<String, dynamic>.from(item);
        payload.remove('_syncing');
        payload.remove('_recovered');
        payload['sync_metadata'] = {
          'client_timestamp': DateTime.now().toIso8601String(),
          'app_version': AppConfig.appVersion,
          'retry_count': item['retry_count'] ?? 0,
        };

        final response = await submitFn(payload);

        if (response['status'] == 'duplicate') {
          successfullySynced.add(item['offline_id']);
          results.add(OfflineSyncResult.duplicate(item['offline_id'], response));
        } else if (response['conflict'] == true) {
          await _saveConflict(item, response);
          successfullySynced.add(item['offline_id']);
          results.add(OfflineSyncResult.conflict(item['offline_id'], response));
        } else if (response['success'] == true) {
          successfullySynced.add(item['offline_id']);
          results.add(OfflineSyncResult.success(item['offline_id'], response));
        } else {
          final retryCount = (item['retry_count'] ?? 0) as int;
          if (retryCount < _maxRetries) {
            item['retry_count'] = retryCount + 1;
            item['last_retry_at'] = DateTime.now().toIso8601String();
            item.remove('_syncing');
            remaining.add(item);
            results.add(OfflineSyncResult.error(item['offline_id'], 'Unexpected server response'));
          } else {
            item.remove('_syncing');
            remaining.add(item);
            results.add(OfflineSyncResult.error(item['offline_id'], 'Unexpected server response'));
          }
        }
      } on ApiException catch (e) {
        final retryCount = (item['retry_count'] ?? 0) as int;
        if (_isRetryableError(e) && retryCount < _maxRetries) {
          item['retry_count'] = retryCount + 1;
          item['last_retry_at'] = DateTime.now().toIso8601String();
          item.remove('_syncing');
          remaining.add(item);
          results.add(OfflineSyncResult.error(item['offline_id'], 'RETRY_${retryCount + 1}/$_maxRetries: ${e.message}'));
        } else {
          await _logSyncError(item, e);
          item.remove('_syncing');
          remaining.add(item); // Keep for manual review
          results.add(OfflineSyncResult.error(item['offline_id'], e.message));
        }
      } catch (e) {
        await _logSyncError(item, e);
        item.remove('_syncing');
        remaining.add(item);
        results.add(OfflineSyncResult.error(item['offline_id'], e.toString()));
      }
    }

    // ═══ FIX: Save ONCE — remaining items only. No intermediate writes. ═══
    await _saveQueue(remaining);
    _invalidatePendingCount();

    _logSyncSummary(results);
    return results;
  }

  bool _isRetryableError(ApiException e) {
    final code = e.code;
    if (code == null) return true;
    return code.startsWith('5') ||
        code == 'NETWORK' ||
        code == 'timeout' ||
        code == 'ETIMEDOUT' ||
        code == 'ECONNREFUSED';
  }

  // ===== CONFLICTS =====

  /// Save a conflict between local and server data for manual resolution.
  /// Public method so SyncService can record conflicts during batch sync.
  Future<void> saveConflict(Map<String, dynamic> local, Map<String, dynamic> server) async {
    try {
      final conflicts = _getConflicts();
      conflicts[local['offline_id']] = {
        'local': local,
        'server': server,
        'detected_at': DateTime.now().toIso8601String(),
        'resolved': false,
      };
      final encrypted = _encryption.encrypt(jsonEncode(conflicts));
      await _safeBox.put(_conflictsKey, encrypted);
    } catch (e) {
      if (kDebugMode) print('Failed to save conflict: $e');
    }
  }

  Future<void> _saveConflict(Map<String, dynamic> local, Map<String, dynamic> server) async {
    return saveConflict(local, server);
  }

  Map<String, dynamic> _getConflicts() {
    final data = _safeBox.get(_conflictsKey);
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
      await _safeBox.put(_conflictsKey, encrypted);
    }
  }

  Future<void> _logSyncError(Map<String, dynamic> item, dynamic error) async {
    if (kDebugMode) print('Sync error for ${item['offline_id']}: $error');
  }

  void _logSyncSummary(List<OfflineSyncResult> results) {
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
    return _withWriteLock(() async {
      final drafts = _getDrafts();
      drafts[formId] = {
        'data': data,
        'saved_at': DateTime.now().toIso8601String(),
      };
      final encrypted = _encryption.encrypt(jsonEncode(drafts));
      await _safeBox.put(_draftsKey, encrypted);
    });
  }

  Map<String, dynamic> _getDrafts() {
    final data = _safeBox.get(_draftsKey);
    if (data == null || data.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(data)));
    } catch (e) {
      if (kDebugMode) print('[OfflineManager] Drafts decrypt error: $e');
      return {};
    }
  }

  Map<String, dynamic>? getDraft(String formId) {
    final drafts = _getDrafts();
    return drafts[formId];
  }

  Set<String> getDraftFormIds() {
    return _getDrafts().keys.toSet();
  }

  Future<void> removeDraft(String formId) async {
    return _withWriteLock(() async {
      final drafts = _getDrafts();
      drafts.remove(formId);
      final encrypted = _encryption.encrypt(jsonEncode(drafts));
      await _safeBox.put(_draftsKey, encrypted);
    });
  }

  // ===== CACHE =====

  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    return _withWriteLock(() async {
      final cache = _getCache();
      cache[key] = {
        'data': data,
        'cached_at': DateTime.now().toIso8601String(),
      };
      final encrypted = _encryption.encrypt(jsonEncode(cache));
      await _safeBox.put(_cacheKey, encrypted);
    });
  }

  Map<String, dynamic> _getCache() {
    final data = _safeBox.get(_cacheKey);
    if (data == null || data.isEmpty) return {};
    try {
      final decrypted = _encryption.decrypt(data);
      return Map<String, dynamic>.from(jsonDecode(decrypted));
    } catch (_) {
      try {
        return Map<String, dynamic>.from(jsonDecode(data));
      } catch (_) {
        return {};
      }
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
    await _safeBox.delete(_cacheKey);
  }

  void dispose() {
    _connectivityController.close();
  }
}
