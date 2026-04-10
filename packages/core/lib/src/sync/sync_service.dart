import 'dart:async';
import '../api/api_client.dart';
import '../config/supabase_config.dart';
import '../offline/offline_manager.dart';
import '../errors/app_exceptions.dart';

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

  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => sync(),
    );

    // Also sync when connectivity changes
    _offline.connectivityStream.listen((isOnline) {
      if (isOnline) sync();
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
  }

  Future<SyncResult> sync() async {
    if (_isSyncing) return SyncResult.empty;
    if (!_offline.isOnline) return SyncResult.empty;

    _isSyncing = true;
    _updateState(isSyncing: true);

    final result = SyncResult();
    final pendingItems = await _offline.getPendingItems();

    if (pendingItems.isEmpty) {
      _isSyncing = false;
      _updateState(isSyncing: false, lastSync: DateTime.now());
      return result;
    }

    _updateState(
      isSyncing: true,
      totalItems: pendingItems.length,
      processedItems: 0,
    );

    // Batch sync (10 items at a time)
    const batchSize = 10;
    for (var i = 0; i < pendingItems.length; i += batchSize) {
      final batch = pendingItems.skip(i).take(batchSize).toList();

      try {
        final response = await _api.callFunction(
          SupabaseConfig.fnSyncOffline,
          {'items': batch},
        );

        final results = response['results'] as List? ?? [];
        final errors = response['errors'] as List? ?? [];

        for (final r in results) {
          if (r['status'] == 'synced' || r['status'] == 'duplicate') {
            await _offline.removeFromQueue(r['offline_id']);
            result.synced++;
          }
        }

        for (final e in errors) {
          result.failed++;
          result.errors.add(SyncError(
            offlineId: e['offline_id'],
            error: e['error'],
          ));
        }
      } catch (e) {
        result.failed += batch.length;
        result.errors.add(SyncError(error: e.toString()));
      }

      _updateState(
        isSyncing: true,
        totalItems: pendingItems.length,
        processedItems: (i + batch.length).clamp(0, pendingItems.length).toInt(),
      );
    }

    _isSyncing = false;
    _updateState(
      isSyncing: false,
      lastSync: DateTime.now(),
      totalItems: pendingItems.length,
      processedItems: pendingItems.length,
    );

    return result;
  }

  void _updateState({
    bool? isSyncing,
    DateTime? lastSync,
    int? totalItems,
    int? processedItems,
  }) {
    _currentState = _currentState.copyWith(
      isSyncing: isSyncing,
      lastSync: lastSync,
      totalItems: totalItems,
      processedItems: processedItems,
    );
    _syncStateController.add(_currentState);
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStateController.close();
  }
}

class SyncState {
  final bool isSyncing;
  final DateTime? lastSync;
  final int totalItems;
  final int processedItems;

  const SyncState({
    this.isSyncing = false,
    this.lastSync,
    this.totalItems = 0,
    this.processedItems = 0,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSync,
    int? totalItems,
    int? processedItems,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSync: lastSync ?? this.lastSync,
      totalItems: totalItems ?? this.totalItems,
      processedItems: processedItems ?? this.processedItems,
    );
  }

  double get progress => totalItems > 0 ? processedItems / totalItems : 1.0;
}

class SyncResult {
  int synced = 0;
  int failed = 0;
  List<SyncError> errors = [];

  SyncResult();
  static SyncResult empty = SyncResult();
}

class SyncError {
  final String? offlineId;
  final String error;

  SyncError({this.offlineId, required this.error});
}
