import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';
import '../errors/app_exceptions.dart';
import 'sync_queue_v2.dart';
// Re-export models from sync_models.dart (already exported by sync_queue_v2.dart)
export 'sync_models.dart'
    show
        FieldCategories,
        DataConflictV2,
        ConflictResolver,
        NetworkSnapshot,
        NetworkStatus;

// ═══════════════════════════════════════════════════════════════════════════════
// INTELLIGENT OFFLINE MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

/// Callback type: submit a batch of items to the server.
/// Must return a list of results, one per item.
typedef BatchSubmitFn = Future<List<SyncItemResult>> Function(
  List<SyncQueueEntry> items,
);

/// Callback type: fetch the latest server version of an entity.
typedef FetchServerVersionFn = Future<Map<String, dynamic>?> Function(
  String entityType,
  String entityId,
);

/// The core offline-first manager.
///
/// Responsibilities:
/// - Monitors connectivity (via ConnectivityUtils or direct)
/// - Enqueues operations with priority
/// - Syncs in batches with exponential backoff
/// - Resolves conflicts automatically (smart merge default)
/// - Exposes reactive NetworkSnapshot stream for UI
class IntelligentOfflineManager {
  final ProductionSyncQueue _queue;
  final Connectivity _connectivity;
  final ConflictStrategy defaultConflictStrategy;

  // Callbacks (set by the app layer)
  BatchSubmitFn? onSubmitBatch;
  FetchServerVersionFn? onFetchServerVersion;

  // State
  bool _isOnline = false;
  bool _isSyncing = false;
  DateTime? _lastOnlineAt;
  DateTime? _lastSyncAt;
  String? _lastError;
  Timer? _autoSyncTimer;
  Timer? _retryTimer;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  final _stateController = StreamController<NetworkSnapshot>.broadcast();
  final _conflictController = StreamController<DataConflictV2>.broadcast();

  /// Reactive stream of network state changes. Use in UI.
  Stream<NetworkSnapshot> get stateStream => _stateController.stream;

  /// Stream of detected conflicts for manual review UI.
  Stream<DataConflictV2> get conflictStream => _conflictController.stream;

  /// Current network snapshot.
  NetworkSnapshot get currentSnapshot => NetworkSnapshot(
        status: _isSyncing
            ? NetworkStatus.syncing
            : _isOnline
                ? NetworkStatus.online
                : NetworkStatus.offline,
        pendingItems: _queue.getCounts().total,
        failedItems: _queue.getCounts().failed,
        lastSyncAt: _lastSyncAt,
        lastOnlineAt: _lastOnlineAt,
        currentError: _lastError,
      );

  IntelligentOfflineManager(
    this._queue,
    this._connectivity, {
    this.defaultConflictStrategy = ConflictStrategy.smartMerge,
  });

  // ─── INITIALIZATION ──────────────────────────────────────────────────────

  Future<void> init() async {
    await _queue.init();
    _startConnectivityMonitor();
    _startAutoSync();
    _startRetryTimer();
    _emitState();
  }

  void _startConnectivityMonitor() {
    _connSub?.cancel();
    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      if (_isOnline) _lastOnlineAt = DateTime.now();

      // On reconnect: trigger immediate sync
      if (wasOffline && _isOnline) {
        if (kDebugMode)
          print('[OfflineMgr] Connection restored — triggering sync');
        Future.delayed(const Duration(seconds: 3), () => syncNow());
      }

      _emitState();
    });

    // Initial check
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (_isOnline) _lastOnlineAt = DateTime.now();
      _emitState();
    }).catchError((_) {});
  }

  /// Auto-sync every 5 minutes when online.
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        if (_isOnline && !_isSyncing && _queue.getCounts().total > 0) {
          syncNow();
        }
      },
    );
  }

  /// Check for retry-ready items every 15 seconds.
  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (_isOnline && !_isSyncing) {
          final ready = _queue.getReadyItems();
          if (ready.isNotEmpty) {
            syncNow();
          }
        }
      },
    );
  }

  // ─── ENQUEUE ─────────────────────────────────────────────────────────────

  /// Queue a form submission for sync. Returns the queue entry ID.
  Future<String> queueSubmission(Map<String, dynamic> data) {
    return _queue.enqueue(
      type: 'form_submission',
      payload: data,
      priority: SyncPriority.critical,
    );
  }

  /// Queue a shortage report for sync.
  Future<String> queueShortage(Map<String, dynamic> data) {
    return _queue.enqueue(
      type: 'shortage_report',
      payload: data,
      priority: SyncPriority.high,
    );
  }

  /// Queue any operation for sync.
  Future<String> enqueue({
    required String type,
    required Map<String, dynamic> payload,
    SyncPriority priority = SyncPriority.normal,
  }) {
    return _queue.enqueue(type: type, payload: payload, priority: priority);
  }

  // ─── SYNC ENGINE ─────────────────────────────────────────────────────────

  /// Trigger an immediate sync cycle.
  /// Safe to call multiple times — won't run concurrently.
  Future<SyncCycleSummary> syncNow({
    int batchSize = 50,
    ConflictStrategy? conflictStrategy,
  }) async {
    if (_isSyncing) return SyncCycleSummary();
    if (!_isOnline) return SyncCycleSummary();
    if (onSubmitBatch == null) {
      if (kDebugMode) print('[OfflineMgr] No onSubmitBatch callback set');
      return SyncCycleSummary();
    }

    _isSyncing = true;
    _lastError = null;
    _emitState();

    int totalSynced = 0;
    int totalDuplicates = 0;
    int totalConflicts = 0;
    int totalFailed = 0;
    int totalRetried = 0;
    final errors = <String>[];

    try {
      // Process in batches until no more ready items
      List<SyncQueueEntry> batch;
      do {
        batch = _queue.getBatch(batchSize);
        if (batch.isEmpty) break;

        if (kDebugMode)
          print('[OfflineMgr] Syncing batch of ${batch.length} items');

        // Mark all as syncing
        for (final item in batch) {
          await _queue.markSyncing(item.id);
        }

        try {
          final results = await onSubmitBatch!(batch);

          for (int i = 0; i < results.length && i < batch.length; i++) {
            final result = results[i];
            final item = batch[i];

            if (result.success && !result.hasConflict) {
              await _queue.markCompleted(item.id);
              totalSynced++;
              if (result.isDuplicate) totalDuplicates++;
            } else if (result.hasConflict) {
              // Handle conflict
              final resolved = await _handleConflict(
                item,
                result.serverData ?? {},
                conflictStrategy ?? defaultConflictStrategy,
              );
              if (resolved != null) {
                // Re-enqueue the resolved version
                await _queue.enqueue(
                  type: item.type,
                  payload: resolved,
                  priority: item.priority,
                  metadata: {...item.metadata, 'conflict_resolved': true},
                );
                await _queue.markCompleted(item.id);
                totalConflicts++;
              } else {
                // Manual review needed
                _conflictController.add(DataConflictV2(
                  id: item.id,
                  entityType: item.type,
                  entityId: item.payload['offline_id'] ?? item.id,
                  localData: item.payload,
                  serverData: result.serverData ?? {},
                  detectedAt: DateTime.now(),
                ));
                await _queue.markCompleted(item.id);
                totalConflicts++;
              }
            } else {
              // Error
              await _queue.markFailed(item.id, result.error ?? 'Unknown error');
              totalFailed++;
              totalRetried++;
              errors.add('${item.id}: ${result.error}');
            }
          }
        } catch (e) {
          // Batch-level error: mark all items as failed
          for (final item in batch) {
            await _queue.markFailed(item.id, 'Batch error: $e');
            totalFailed++;
            totalRetried++;
          }
          errors.add('Batch error: $e');
        }
      } while (batch.length == batchSize);

      _lastSyncAt = DateTime.now();
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) print('[OfflineMgr] Sync error: $e');
    }

    _isSyncing = false;
    _emitState();

    final summary = SyncCycleSummary(
      totalItems: totalSynced + totalDuplicates + totalConflicts + totalFailed,
      synced: totalSynced,
      duplicates: totalDuplicates,
      conflicts: totalConflicts,
      failed: totalFailed,
      retried: totalRetried,
      errors: errors,
    );

    if (kDebugMode) print('[OfflineMgr] $summary');
    return summary;
  }

  /// Handle a single conflict: auto-resolve if possible, else emit for UI.
  Future<Map<String, dynamic>?> _handleConflict(
    SyncQueueEntry item,
    Map<String, dynamic> serverData,
    ConflictStrategy strategy,
  ) async {
    final conflict = DataConflictV2(
      id: item.id,
      entityType: item.type,
      entityId: item.payload['offline_id'] ?? item.id,
      localData: item.payload,
      serverData: serverData,
      detectedAt: DateTime.now(),
    );

    if (strategy == ConflictStrategy.manualReview) {
      _conflictController.add(conflict);
      return null;
    }

    // Auto-resolve
    final resolved = ConflictResolver.resolve(conflict, strategy);
    if (kDebugMode) {
      print(
          '[OfflineMgr] Auto-resolved conflict for ${item.id} using ${strategy.name}');
    }
    return resolved;
  }

  // ─── FAILED ITEMS ────────────────────────────────────────────────────────

  List<SyncQueueEntry> get failedItems => _queue.getFailedItems();

  Future<void> retryFailed(String id) => _queue.retryFailed(id);
  Future<void> retryAllFailed() => _queue.retryAllFailed();
  Future<void> deleteFailed(String id) => _queue.deleteFailed(id);

  // ─── UI HELPERS ──────────────────────────────────────────────────────────

  QueueCounts get counts => _queue.getCounts();
  Stream<QueueCounts> get countsStream => _queue.countsStream;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(currentSnapshot);
    }
  }

  // ─── CLEANUP ─────────────────────────────────────────────────────────────

  void dispose() {
    _connSub?.cancel();
    _autoSyncTimer?.cancel();
    _retryTimer?.cancel();
    _stateController.close();
    _conflictController.close();
    _queue.dispose();
  }
}
