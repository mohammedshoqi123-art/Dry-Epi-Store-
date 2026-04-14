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
  bool _isSyncing = false;
  final _syncStateController = StreamController<SyncState>.broadcast();

  Stream<SyncState> get syncState => _syncStateController.stream;
  SyncState _currentState = const SyncState();
  SyncState get currentState => _currentState;

  SyncService(this._api, this._offline) {
    // ═══ FIX: Listen for connectivity changes and trigger sync on reconnect ═══
    // When the device reconnects after being offline, immediately sync pending items.
    _offline.connectivityStream.listen((isOnline) {
      if (isOnline && _offline.pendingCount > 0) {
        if (kDebugMode) print('[SyncService] Reconnected — triggering sync (${_offline.pendingCount} items)');
        _attemptSync('reconnect');
      }
    });
  }

  /// Start periodic auto-sync with proper timing.
  /// ═══ FIX: More resilient auto-sync that doesn't depend on connectivity state ═══
  /// The actual network call will determine if we're online — the connectivity
  /// plugin can misreport status (VPN, captive portals, etc.).
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _attemptSync('timer'),
    );
    // ═══ FIX: Try initial sync after 5 seconds (shorter delay) ═══
    Timer(const Duration(seconds: 5), () => _attemptSync('initial'));
    if (kDebugMode) print('[SyncService] Auto-sync started (every 2 min)');
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    if (kDebugMode) print('[SyncService] Auto-sync stopped');
  }

  /// Internal sync attempt with logging context.
  /// ═══ FIX: Don't block on connectivity check — try the actual call. ═══
  Future<void> _attemptSync(String trigger) async {
    if (_isSyncing) return;
    if (!_offline.isInitialized) return;

    final pending = _offline.pendingCount;
    if (pending == 0) return;

    if (kDebugMode) print('[SyncService] Auto-sync triggered by $trigger ($pending items)');
    await sync();
  }

  /// Perform a sync cycle. Returns summary of results.
  /// ═══ FIX: More robust sync that handles edge cases ═══
  Future<SyncCycleResult> sync() async {
    if (_isSyncing) {
      // ═══ FIX: Auto-reset stale lock after 3 minutes ═══
      // This prevents the sync from being permanently blocked after a crash
      if (kDebugMode) print('[SyncService] Sync already in progress, skipping');
      return SyncCycleResult.empty();
    }
    if (!_offline.isInitialized) return SyncCycleResult.empty();

    final pending = _offline.pendingCount;
    if (pending == 0) return SyncCycleResult.empty();

    // ═══ FIX: Don't trust isOnline blindly — try the actual sync and handle failures.
    // The connectivity plugin can misreport status (VPN, proxy, captive portal).
    if (!_offline.isOnline) {
      if (kDebugMode) print('[SyncService] Connectivity reports offline, attempting sync anyway...');
    }

    _isSyncing = true;
    _updateState(isSyncing: true);

    // ═══ FIX: Safety timeout to auto-reset _isSyncing ═══
    Timer(const Duration(minutes: 3), () {
      if (_isSyncing) {
        if (kDebugMode) print('[SyncService] WARNING: Sync lock auto-reset after 3min timeout');
        _isSyncing = false;
        _updateState(isSyncing: false);
      }
    });

    final result = SyncCycleResult();

    try {
      final syncResults = await _offline.syncPendingItems((item) async {
        try {
          final response = await _api.callFunction(
            SupabaseConfig.fnSyncOffline,
            {'items': [item]},
          );
          final results = (response['results'] as List?) ?? [];
          final errors = (response['errors'] as List?) ?? [];

          if (results.isNotEmpty) {
            final r = results.first;
            return {'success': true, 'status': r['status'], ...r};
          }
          if (errors.isNotEmpty) {
            final e = errors.first;
            return {'success': false, 'error': e['error']};
          }
          return {'success': false, 'error': 'Unknown sync response'};
        } catch (itemError) {
          // ═══ FIX: Catch per-item errors so one bad item doesn't kill the whole batch ═══
          if (kDebugMode) print('[SyncService] Item sync error: $itemError');
          return {'success': false, 'error': itemError.toString()};
        }
      }).timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          if (kDebugMode) print('[SyncService] Sync timed out after 2 minutes');
          return <OfflineSyncResult>[];
        },
      );

      for (final sr in syncResults) {
        switch (sr.status) {
          case OfflineSyncStatus.success:
            result.synced++;
          case OfflineSyncStatus.duplicate:
            result.duplicates++;
          case OfflineSyncStatus.conflict:
            result.conflicts++;
            result.conflictDetails.add(sr);
          case OfflineSyncStatus.error:
            result.failed++;
            result.errors.add(SyncError(offlineId: sr.offlineId, error: sr.errorMessage ?? 'Unknown'));
        }
      }

      // If we synced successfully, update connectivity status
      if (result.synced > 0 || result.duplicates > 0) {
        _offline.updateConnectivity(true);
      }
    } catch (e) {
      if (kDebugMode) print('[SyncService] Sync cycle error: $e');
      result.errors.add(SyncError(error: e.toString()));

      // If the error is network-related, update connectivity status
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
