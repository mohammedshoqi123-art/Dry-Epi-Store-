import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';
import '../errors/app_exceptions.dart';
import 'sync_queue_v2.dart';
import 'enhanced_sync_service.dart' show ConflictStrategy;

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT RESOLUTION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
// ConflictStrategy is imported from enhanced_sync_service.dart to avoid duplicates.

/// Field categories for smart merge conflict resolution.
class FieldCategories {
  /// Fields where the client (field worker) always has the latest truth.
  static const fieldDataKeys = {
    'data', 'gps_lat', 'gps_lng', 'gps_accuracy',
    'photos', 'notes', 'submitted_at', 'device_id',
  };

  /// Fields managed by admin/server that should not be overwritten by client.
  static const adminKeys = {
    'status', 'reviewed_by', 'reviewed_at', 'approved_by',
    'approved_at', 'rejection_reason', 'admin_notes',
  };

  static bool isFieldData(String key) => fieldDataKeys.contains(key);
  static bool isAdmin(String key) => adminKeys.contains(key);
}

/// A detected conflict between local and server versions.
class DataConflictV2 {
  final String id;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime detectedAt;
  final ConflictStrategy? resolvedStrategy;
  final Map<String, dynamic>? resolvedData;
  final bool resolved;

  const DataConflictV2({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localData,
    required this.serverData,
    required this.detectedAt,
    this.resolvedStrategy,
    this.resolvedData,
    this.resolved = false,
  });

  /// Fields that actually differ between local and server.
  List<String> get differingFields {
    final allKeys = {...localData.keys, ...serverData.keys};
    return allKeys.where((key) {
      if (const {'updated_at', 'created_at', 'id', 'offline_id'}.contains(key)) return false;
      return localData[key] != serverData[key];
    }).toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'local_data': localData,
        'server_data': serverData,
        'detected_at': detectedAt.toIso8601String(),
        'resolved_strategy': resolvedStrategy?.name,
        'resolved_data': resolvedData,
        'resolved': resolved,
      };

  factory DataConflictV2.fromJson(Map<String, dynamic> json) => DataConflictV2(
        id: json['id'] as String,
        entityType: json['entity_type'] as String,
        entityId: json['entity_id'] as String,
        localData: Map<String, dynamic>.from(json['local_data'] as Map),
        serverData: Map<String, dynamic>.from(json['server_data'] as Map),
        detectedAt: DateTime.parse(json['detected_at'] as String),
        resolvedStrategy: json['resolved_strategy'] != null
            ? ConflictStrategy.values.byName(json['resolved_strategy'] as String)
            : null,
        resolvedData: json['resolved_data'] != null
            ? Map<String, dynamic>.from(json['resolved_data'] as Map)
            : null,
        resolved: json['resolved'] as bool? ?? false,
      );
}

/// Conflict resolver with multiple strategies.
class ConflictResolver {
  /// Auto-resolve a conflict using the given strategy.
  /// Returns the merged data to send to the server.
  static Map<String, dynamic> resolve(
    DataConflictV2 conflict,
    ConflictStrategy strategy,
  ) {
    switch (strategy) {
      case ConflictStrategy.serverWins:
        return conflict.serverData;

      case ConflictStrategy.localWins:
        return conflict.localData;

      case ConflictStrategy.smartMerge:
        return _smartMerge(conflict.localData, conflict.serverData);

      case ConflictStrategy.manualReview:
        // Cannot auto-resolve; return local as placeholder
        return conflict.localData;
    }
  }

  /// Smart merge: field data (GPS, photos, notes) from client wins,
  /// admin fields (status, reviewer) from server wins.
  static Map<String, dynamic> _smartMerge(
    Map<String, dynamic> local,
    Map<String, dynamic> server,
  ) {
    final merged = Map<String, dynamic>.from(server); // Start with server

    for (final key in local.keys) {
      if (FieldCategories.isFieldData(key)) {
        // Client field data wins
        merged[key] = local[key];
      }
      // Admin keys keep server values (already set)
      // Non-categorized keys: use the one with the newer timestamp
    }

    // Add merge metadata
    merged['_conflict_resolved'] = true;
    merged['_resolution_strategy'] = 'smart_merge';
    merged['_resolved_at'] = DateTime.now().toIso8601String();

    return merged;
  }

  /// Detect if two versions conflict.
  /// Returns null if no conflict, or a DataConflictV2 if they do.
  static DataConflictV2? detect({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
    required DateTime? localBaseTimestamp,
  }) {
    final serverUpdated = DateTime.tryParse(serverData['updated_at'] ?? '');

    if (serverUpdated == null || localBaseTimestamp == null) return null;

    // Conflict only if server was updated AFTER our last known version
    if (!serverUpdated.isAfter(localBaseTimestamp)) return null;

    // Check for actual data differences
    final hasDifferences = _hasDataDifferences(localData, serverData);
    if (!hasDifferences) return null;

    return DataConflictV2(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      entityType: entityType,
      entityId: entityId,
      localData: localData,
      serverData: serverData,
      detectedAt: DateTime.now(),
    );
  }

  static bool _hasDataDifferences(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    const skipKeys = {'updated_at', 'created_at', 'id', 'offline_id', 'synced_at'};
    for (final key in a.keys) {
      if (skipKeys.contains(key)) continue;
      if (a[key] != b[key]) return true;
    }
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTELLIGENT OFFLINE MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

/// Network state for UI display.
enum NetworkStatus { online, offline, syncing }

class NetworkSnapshot {
  final NetworkStatus status;
  final int pendingItems;
  final int failedItems;
  final DateTime? lastSyncAt;
  final DateTime? lastOnlineAt;
  final String? currentError;

  const NetworkSnapshot({
    required this.status,
    this.pendingItems = 0,
    this.failedItems = 0,
    this.lastSyncAt,
    this.lastOnlineAt,
    this.currentError,
  });

  bool get isOnline => status != NetworkStatus.offline;
  bool get isSyncing => status == NetworkStatus.syncing;
  bool get hasPending => pendingItems > 0;
  bool get hasFailed => failedItems > 0;

  Duration? get offlineDuration =>
      !isOnline && lastOnlineAt != null
          ? DateTime.now().difference(lastOnlineAt!)
          : null;

  /// Emoji indicator for simple UI
  String get indicator => switch (status) {
        NetworkStatus.online => hasPending ? '🟡' : '🟢',
        NetworkStatus.syncing => '🟡',
        NetworkStatus.offline => '🔴',
      };

  /// Arabic status text
  String get statusText => switch (status) {
        NetworkStatus.online => hasPending
            ? 'متصل - $pendingItems سجل في الانتظار'
            : 'متصل - كل البيانات مزامنة',
        NetworkStatus.syncing => 'جاري رفع $pendingItems سجل...',
        NetworkStatus.offline => pendingItems > 0
            ? 'غير متصل - $pendingItems سجل بانتظار المزامنة'
            : 'غير متصل - العمل بدون إنترنت',
      };
}

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
        if (kDebugMode) print('[OfflineMgr] Connection restored — triggering sync');
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

        if (kDebugMode) print('[OfflineMgr] Syncing batch of ${batch.length} items');

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
      print('[OfflineMgr] Auto-resolved conflict for ${item.id} using ${strategy.name}');
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
