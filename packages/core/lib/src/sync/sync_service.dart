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

  SyncService(this._api, this._offline);

  /// Start periodic auto-sync (every 2 minutes — more responsive than 5)
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => sync(),
    );
    // Also try an initial sync after 10 seconds
    Timer(const Duration(seconds: 10), () => sync());
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
  }

  /// Perform a sync cycle. Returns summary of results.
  /// FIX: Don't trust isOnline blindly — try the actual sync and handle failures.
  /// The connectivity plugin can misreport status (VPN, proxy, etc).
  Future<SyncCycleResult> sync() async {
    if (_isSyncing) return SyncCycleResult.empty();
    if (!_offline.isInitialized) return SyncCycleResult.empty();

    final pending = _offline.pendingCount;
    if (pending == 0) return SyncCycleResult.empty();

    // Only skip if we KNOW we're offline AND there have been recent failures
    // Otherwise, try the sync — the actual network call will determine if we're connected
    if (!_offline.isOnline) {
      // Still try, but log it
      if (kDebugMode) print('[SyncService] Connectivity reports offline, attempting sync anyway...');
    }

    _isSyncing = true;
    _updateState(isSyncing: true);

    final result = SyncCycleResult();

    try {
      final syncResults = await _offline.syncPendingItems((item) async {
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
          'failed=${result.failed}');
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
    _syncStateController.add(_currentState);
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
