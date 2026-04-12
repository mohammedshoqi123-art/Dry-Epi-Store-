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

  /// Start periodic auto-sync (every 5 minutes + on connectivity change)
  /// Automatically triggers sync when connectivity is restored with pending items.
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => sync(),
    );

    // Auto-sync when connectivity is restored with a short delay
    _offline.connectivityStream.listen((isOnline) {
      if (isOnline && _offline.pendingCount > 0) {
        Future.delayed(const Duration(seconds: 2), () => sync());
      }
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
  }

  /// Perform a sync cycle. Returns summary of results.
  Future<SyncCycleResult> sync() async {
    if (_isSyncing) return SyncCycleResult.empty();
    if (!_offline.isOnline) return SyncCycleResult.empty();

    _isSyncing = true;
    _updateState(isSyncing: true);

    final result = SyncCycleResult();

    try {
      // Use the improved OfflineManager's syncPendingItems with retry/conflict handling
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
      });

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
    } catch (e) {
      if (kDebugMode) print('Sync cycle error: $e');
      result.errors.add(SyncError(error: e.toString()));
    }

    _isSyncing = false;
    _updateState(
      isSyncing: false,
      lastSync: DateTime.now(),
      pendingCount: _offline.pendingCount,
    );

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
