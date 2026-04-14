import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../config/supabase_config.dart';
import '../offline/offline_manager.dart';

/// Manages background synchronization of offline data.
/// Handles batch syncing, conflict resolution, and retry logic.
class SyncService {
  final ApiClient _api;
  final OfflineManager _offline;
  Timer? _syncTimer;
  DateTime? _syncLockTime;
  bool _isSyncing = false;
  static const int _maxBatchSize = 50;
  final _syncStateController = StreamController<SyncState>.broadcast();

  Stream<SyncState> get syncState => _syncStateController.stream;
  SyncState _currentState = const SyncState();
  SyncState get currentState => _currentState;

  SyncService(this._api, this._offline) {
    // ═══ FIX: Listen for connectivity changes and trigger sync on reconnect ═══
    _offline.connectivityStream.listen((isOnline) {
      if (isOnline && _offline.pendingCount > 0) {
        if (kDebugMode) print('[SyncService] Reconnected — triggering sync (${_offline.pendingCount} items)');
        _attemptSync('reconnect');
      }
    });
  }

  /// Start periodic auto-sync with proper timing.
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _attemptSync('timer'),
    );
    Timer(const Duration(seconds: 5), () => _attemptSync('initial'));
    if (kDebugMode) print('[SyncService] Auto-sync started (every 2 min)');
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    if (kDebugMode) print('[SyncService] Auto-sync stopped');
  }

  /// Internal sync attempt with logging context.
  Future<void> _attemptSync(String trigger) async {
    if (_isSyncing) return;
    if (!_offline.isInitialized) return;

    final pending = _offline.pendingCount;
    if (pending == 0) return;

    if (kDebugMode) print('[SyncService] Auto-sync triggered by $trigger ($pending items)');
    await sync();
  }

  /// Perform a sync cycle. Returns summary of results.
  /// ═══ FIX: Batch all items into a SINGLE edge function call instead of
  /// one call per item. This prevents the restart-on-sync bug caused by
  /// N rapid edge function invocations overwhelming the system. ═══
  Future<SyncCycleResult> sync() async {
    // ═══ FIX: Use timestamp-based lock with auto-expiry instead of boolean ═══
    // A boolean lock can get stuck permanently if the app crashes during sync.
    // With timestamp, we can auto-recover after 2 minutes.
    if (_isSyncing) {
      final lockAge = _syncLockTime != null
          ? DateTime.now().difference(_syncLockTime!).inSeconds
          : 0;
      if (lockAge > 120) {
        if (kDebugMode) print('[SyncService] Stale lock detected (${lockAge}s old), resetting');
        _isSyncing = false;
      } else {
        if (kDebugMode) print('[SyncService] Sync already in progress (${lockAge}s), skipping');
        return SyncCycleResult.empty();
      }
    }
    if (!_offline.isInitialized) return SyncCycleResult.empty();

    final pendingItems = await _offline.getPendingItems();
    if (pendingItems.isEmpty) return SyncCycleResult.empty();

    _isSyncing = true;
    _syncLockTime = DateTime.now();
    _updateState(isSyncing: true);

    final result = SyncCycleResult();

    try {
      // ═══ FIX: Process items in batches, calling the edge function once per batch ═══
      // Instead of calling the edge function 50 times for 50 items,
      // we send 1 call with all 50 items. The edge function already supports this.
      for (int offset = 0; offset < pendingItems.length; offset += _maxBatchSize) {
        final batchEnd = (offset + _maxBatchSize).clamp(0, pendingItems.length);
        final batch = pendingItems.sublist(offset, batchEnd);

        if (kDebugMode) print('[SyncService] Sending batch: ${batch.length} items (offset $offset)');

        try {
          // Prepare batch payload — strip internal fields
          final items = batch.map((item) {
            final payload = Map<String, dynamic>.from(item);
            payload.remove('_syncing');
            payload.remove('_recovered');
            return payload;
          }).toList();

          // ═══ SINGLE call to edge function with full batch ═══
          final response = await _api.callFunction(
            SupabaseConfig.fnSyncOffline,
            {'items': items},
          ).timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              if (kDebugMode) print('[SyncService] Batch sync timed out');
              throw TimeoutException('Batch sync timed out after 60s');
            },
          );

          final serverResults = (response['results'] as List?) ?? [];
          final serverErrors = (response['errors'] as List?) ?? [];

          // Process results per item
          for (int i = 0; i < batch.length; i++) {
            final item = batch[i];
            final offlineId = item['offline_id'] as String? ?? '';

            // Find matching server result
            final match = serverResults.cast<Map<String, dynamic>>().firstWhere(
              (r) => r['offline_id'] == offlineId,
              orElse: () => <String, dynamic>{},
            );

            if (match.isNotEmpty) {
              final status = match['status'] as String? ?? 'error';
              switch (status) {
                case 'synced':
                  await _offline.removeFromQueue(offlineId);
                  result.synced++;
                case 'duplicate':
                  await _offline.removeFromQueue(offlineId);
                  result.duplicates++;
                case 'conflict':
                  await _offline.saveConflict(item, match);
                  await _offline.removeFromQueue(offlineId);
                  result.conflicts++;
                  result.conflictDetails.add(OfflineSyncResult.conflict(offlineId, match));
                default:
                  // Error — check retry count
                  final retryCount = (item['retry_count'] ?? 0) as int;
                  if (retryCount < 3) {
                    item['retry_count'] = retryCount + 1;
                    item['last_retry_at'] = DateTime.now().toIso8601String();
                    result.failed++;
                    result.errors.add(SyncError(offlineId: offlineId, error: match['error'] ?? 'Unknown error'));
                  } else {
                    await _offline.removeFromQueue(offlineId);
                    result.failed++;
                    result.errors.add(SyncError(offlineId: offlineId, error: match['error'] ?? 'Max retries exceeded'));
                  }
              }
            } else {
              // Check server errors for this item
              final errMatch = serverErrors.cast<Map<String, dynamic>>().firstWhere(
                (e) => e['offline_id'] == offlineId,
                orElse: () => <String, dynamic>{},
              );
              final retryCount = (item['retry_count'] ?? 0) as int;
              if (retryCount < 3) {
                item['retry_count'] = retryCount + 1;
                item['last_retry_at'] = DateTime.now().toIso8601String();
              }
              result.failed++;
              result.errors.add(SyncError(
                offlineId: offlineId,
                error: errMatch['error'] ?? 'No response for item',
              ));
            }
          }
        } on TimeoutException {
          // Batch timeout — items remain in queue for retry
          for (final item in batch) {
            final retryCount = (item['retry_count'] ?? 0) as int;
            if (retryCount < 3) {
              item['retry_count'] = retryCount + 1;
              item['last_retry_at'] = DateTime.now().toIso8601String();
            }
            result.failed++;
            result.errors.add(SyncError(
              offlineId: item['offline_id'] as String? ?? '',
              error: 'Batch timeout',
            ));
          }
        } catch (e) {
          // Batch error — items remain in queue for retry
          if (kDebugMode) print('[SyncService] Batch error: $e');
          for (final item in batch) {
            final retryCount = (item['retry_count'] ?? 0) as int;
            if (retryCount < 3) {
              item['retry_count'] = retryCount + 1;
              item['last_retry_at'] = DateTime.now().toIso8601String();
            }
            result.failed++;
            result.errors.add(SyncError(
              offlineId: item['offline_id'] as String? ?? '',
              error: e.toString(),
            ));
          }
        }
      }

      // If we synced successfully, update connectivity status
      if (result.synced > 0 || result.duplicates > 0) {
        _offline.updateConnectivity(true);
      }
    } catch (e) {
      if (kDebugMode) print('[SyncService] Sync cycle error: $e');
      result.errors.add(SyncError(error: e.toString()));

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') ||
          errorStr.contains('socket') ||
          errorStr.contains('connection') ||
          errorStr.contains('failed host') ||
          errorStr.contains('timeout')) {
        _offline.updateConnectivity(false);
      }
    } finally {
      _isSyncing = false;
      _syncLockTime = null;
      _updateState(
        isSyncing: false,
        lastSync: DateTime.now(),
        pendingCount: _offline.pendingCount,
      );
    }

    if (kDebugMode) {
      print('[SyncService] Sync complete: synced=${result.synced}, '
          'duplicates=${result.duplicates}, conflicts=${result.conflicts}, '
          'failed=${result.failed}, remaining=${_offline.pendingCount}');
    }

    return result;
  }

  /// Get unresolved conflicts for manual resolution
  List<Map<String, dynamic>> getConflicts() {
    return _offline.getUnresolvedConflicts();
  }

  /// Resolve a conflict
  Future<void> resolveConflict(String offlineId, {bool useLocal = false}) async {
    await _offline.resolveConflict(offlineId, useLocal: useLocal);
  }

  void _updateState({
    bool? isSyncing,
    DateTime? lastSync,
    int? pendingCount,
  }) {
    _currentState = _currentState.copyWith(
      isSyncing: isSyncing,
      lastSync: lastSync,
      pendingCount: pendingCount,
    );
    if (!_syncStateController.isClosed) {
      _syncStateController.add(_currentState);
    }
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStateController.close();
  }
}

/// State of the sync service
class SyncState {
  final bool isSyncing;
  final DateTime? lastSync;
  final int pendingCount;

  const SyncState({
    this.isSyncing = false,
    this.lastSync,
    this.pendingCount = 0,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSync,
    int? pendingCount,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSync: lastSync ?? this.lastSync,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

/// Result of a complete sync cycle
class SyncCycleResult {
  int synced = 0;
  int duplicates = 0;
  int conflicts = 0;
  int failed = 0;
  List<SyncError> errors = [];
  List<OfflineSyncResult> conflictDetails = [];

  SyncCycleResult();
  factory SyncCycleResult.empty() => SyncCycleResult();

  bool get hasErrors => errors.isNotEmpty;
  bool get hasConflicts => conflicts > 0;
  int get total => synced + duplicates + conflicts + failed;

  @override
  String toString() => 'SyncCycleResult(synced=$synced, dup=$duplicates, conflict=$conflicts, failed=$failed)';
}

/// Individual sync error
class SyncError {
  final String? offlineId;
  final String error;

  SyncError({this.offlineId, required this.error});

  @override
  String toString() => 'SyncError(${offlineId ?? "?"}: $error)';
}
