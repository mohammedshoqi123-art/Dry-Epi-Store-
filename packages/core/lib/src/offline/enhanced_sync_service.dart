import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_config.dart';
import '../errors/app_exceptions.dart';

/// Advanced connectivity state with quality metrics
enum ConnectionQuality { excellent, good, poor, offline }

/// Smart connection state with pending items count and quality
class NetworkState {
  final bool isOnline;
  final ConnectionQuality quality;
  final int pendingItems;
  final DateTime? lastOnline;
  final DateTime? lastSync;
  final Duration? offlineDuration;

  const NetworkState({
    required this.isOnline,
    this.quality = ConnectionQuality.offline,
    this.pendingItems = 0,
    this.lastOnline,
    this.lastSync,
    this.offlineDuration,
  });

  NetworkState copyWith({
    bool? isOnline,
    ConnectionQuality? quality,
    int? pendingItems,
    DateTime? lastOnline,
    DateTime? lastSync,
  }) {
    return NetworkState(
      isOnline: isOnline ?? this.isOnline,
      quality: quality ?? this.quality,
      pendingItems: pendingItems ?? this.pendingItems,
      lastOnline: lastOnline ?? this.lastOnline,
      lastSync: lastSync ?? this.lastSync,
      offlineDuration: isOnline == false && lastOnline != null
          ? DateTime.now().difference(lastOnline)
          : null,
    );
  }

  String get qualityText {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 'ممتاز';
      case ConnectionQuality.good:
        return 'جيد';
      case ConnectionQuality.poor:
        return 'ضعيف';
      case ConnectionQuality.offline:
        return 'غير متصل';
    }
  }

  String get statusMessage {
    if (!isOnline) {
      if (pendingItems > 0) {
        return 'غير متصل - $pendingItems عنصر في الانتظار';
      }
      return 'غير متصل - العمل في وضع بدون إنترنت';
    }
    if (pendingItems > 0) {
      return 'متصل ($qualityText) - جاري مزامنة $pendingItems عنصر...';
    }
    return 'متصل ($qualityText)';
  }
}

/// Conflict resolution strategy
enum ConflictStrategy { localWins, serverWins, merge, manual }

/// Single conflict record
class DataConflict {
  final String id;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime detectedAt;
  final Map<String, dynamic>? mergedData;
  final ConflictStrategy? resolvedStrategy;
  final bool resolved;

  DataConflict({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localData,
    required this.serverData,
    DateTime? detectedAt,
    this.mergedData,
    this.resolvedStrategy,
    this.resolved = false,
  }) : detectedAt = detectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'local_data': localData,
        'server_data': serverData,
        'detected_at': detectedAt.toIso8601String(),
        'merged_data': mergedData,
        'resolved_strategy': resolvedStrategy?.name,
        'resolved': resolved,
      };

  factory DataConflict.fromJson(Map<String, dynamic> json) => DataConflict(
        id: json['id'],
        entityType: json['entity_type'],
        entityId: json['entity_id'],
        localData: Map<String, dynamic>.from(json['local_data']),
        serverData: Map<String, dynamic>.from(json['server_data']),
        detectedAt: DateTime.parse(json['detected_at']),
        mergedData: json['merged_data'],
        resolvedStrategy: json['resolved_strategy'] != null
            ? ConflictStrategy.values.byName(json['resolved_strategy'])
            : null,
        resolved: json['resolved'] ?? false,
      );
}

/// Sync result for a single change
class ChangeSyncResult {
  final String changeId;
  final bool success;
  final bool hasConflict;
  final DataConflict? conflict;
  final String? error;

  ChangeSyncResult.success(this.changeId)
      : success = true,
        hasConflict = false,
        conflict = null,
        error = null;

  ChangeSyncResult.conflict(this.changeId, this.conflict)
      : success = false,
        hasConflict = true,
        error = null;

  ChangeSyncResult.error(this.changeId, this.error)
      : success = false,
        hasConflict = false,
        conflict = null;
}

/// Enhanced sync service with intelligent connection management,
/// conflict resolution, and auto-sync on reconnection.
class EnhancedSyncService {
  final Box<String> _offlineBox;
  final Connectivity _connectivity;
  static const String _pendingKey = 'enhanced_pending';
  static const String _conflictsKey = 'enhanced_conflicts';
  static const String _stateKey = 'sync_state';
  static const String _historyKey = 'sync_history';
  static const int _maxRetries = 5;
  static const Duration _autoSyncInterval = Duration(minutes: 5);
  static const Duration _reconnectSyncDelay = Duration(seconds: 3);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  Timer? _qualityTimer;
  bool _isOnline = false;
  DateTime? _lastOnline;
  DateTime? _lastSync;
  int _pendingCount = 0;

  final _stateController = StreamController<NetworkState>.broadcast();
  final _conflictController = StreamController<DataConflict>.broadcast();
  final _syncResultController = StreamController<SyncBatchResult>.broadcast();

  Stream<NetworkState> get connectionState => _stateController.stream;
  Stream<DataConflict> get onConflictDetected => _conflictController.stream;
  Stream<SyncBatchResult> get onSyncComplete => _syncResultController.stream;

  NetworkState get currentState => NetworkState(
        isOnline: _isOnline,
        quality: _measureQuality(),
        pendingItems: _pendingCount,
        lastOnline: _lastOnline,
        lastSync: _lastSync,
      );

  /// Callback to submit a single change to the server
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> change)?
      onSubmitChange;

  /// Callback to fetch latest server version for conflict detection
  final Future<Map<String, dynamic>?> Function(
      String entityType, String entityId)? onFetchServerVersion;

  EnhancedSyncService(
    this._offlineBox,
    this._connectivity, {
    this.onSubmitChange,
    this.onFetchServerVersion,
  });

  Future<void> init() async {
    _pendingCount = _getPendingChanges().length;
    _initConnectivityListener();
    _startQualityMonitoring();
    _emitState();
  }

  void _initConnectivityListener() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      if (_isOnline) {
        _lastOnline = DateTime.now();
      }

      if (wasOffline && _isOnline) {
        _onReconnected();
      } else if (!wasOffline && !_isOnline) {
        _onDisconnected();
      }

      _emitState();
    });

    // Initial check
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (_isOnline) _lastOnline = DateTime.now();
      _emitState();
    });
  }

  void _startQualityMonitoring() {
    _qualityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _emitState();
    });
  }

  ConnectionQuality _measureQuality() {
    if (!_isOnline) return ConnectionQuality.offline;
    // In a real implementation, this would measure latency/bandwidth
    // For now, return good as default when online
    return ConnectionQuality.good;
  }

  void _onReconnected() {
    if (kDebugMode) print('[EnhancedSync] Connection restored');
    // Delayed sync on reconnect to let connection stabilize
    Future.delayed(_reconnectSyncDelay, () {
      if (_isOnline && _pendingCount > 0) {
        syncWithConflictResolution();
      }
    });
    startAutoSync();
  }

  void _onDisconnected() {
    if (kDebugMode) print('[EnhancedSync] Connection lost');
    stopAutoSync();
  }

  void _emitState() {
    _stateController.add(currentState);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PENDING CHANGES QUEUE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add a change to the pending queue
  Future<void> addPendingChange(Map<String, dynamic> change) async {
    final pending = _getPendingChanges();
    change['queued_at'] = DateTime.now().toIso8601String();
    change['retry_count'] = 0;
    change['change_id'] = change['change_id'] ?? DateTime.now().microsecondsSinceEpoch.toString();
    pending.add(change);
    await _savePendingChanges(pending);
    _pendingCount = pending.length;
    _emitState();
  }

  List<Map<String, dynamic>> _getPendingChanges() {
    final data = _offlineBox.get(_pendingKey);
    if (data == null || data.isEmpty) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePendingChanges(List<Map<String, dynamic>> changes) async {
    await _offlineBox.put(_pendingKey, jsonEncode(changes));
  }

  int get pendingCount => _pendingCount;

  List<Map<String, dynamic>> get pendingChanges => _getPendingChanges();

  // ═══════════════════════════════════════════════════════════════════════════
  // SYNC WITH CONFLICT RESOLUTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sync all pending changes with intelligent conflict resolution
  Future<SyncBatchResult> syncWithConflictResolution() async {
    if (!_isOnline) return SyncBatchResult.offline();
    if (onSubmitChange == null) {
      if (kDebugMode) print('[EnhancedSync] No submit callback configured');
      return SyncBatchResult.error('No submit callback');
    }

    final pending = _getPendingChanges();
    if (pending.isEmpty) return SyncBatchResult.empty();

    final result = SyncBatchResult();
    final remaining = <Map<String, dynamic>>[];

    for (final change in pending) {
      try {
        final changeResult = await _syncSingleChange(change);

        if (changeResult.success) {
          result.synced++;
        } else if (changeResult.hasConflict) {
          result.conflicts++;
          if (changeResult.conflict != null) {
            result.conflictList.add(changeResult.conflict!);
            _conflictController.add(changeResult.conflict!);
          }
        } else {
          final retryCount = (change['retry_count'] ?? 0) as int;
          if (retryCount < _maxRetries) {
            change['retry_count'] = retryCount + 1;
            change['last_retry'] = DateTime.now().toIso8601String();
            remaining.add(change);
            result.retried++;
          } else {
            result.failed++;
            result.errors.add('${change['change_id']}: ${changeResult.error}');
            // Keep failed items for manual review
            remaining.add(change);
          }
        }
      } catch (e) {
        if (kDebugMode) print('[EnhancedSync] Error syncing change: $e');
        result.failed++;
        result.errors.add('${change['change_id']}: $e');
        remaining.add(change);
      }
    }

    // Update queue
    await _savePendingChanges(remaining);
    _pendingCount = remaining.length;
    _lastSync = DateTime.now();

    // Save sync history
    await _saveSyncHistory(result);

    _emitState();
    _syncResultController.add(result);

    if (kDebugMode) {
      print('[EnhancedSync] Sync complete: ${result.summary}');
    }

    return result;
  }

  Future<ChangeSyncResult> _syncSingleChange(
      Map<String, dynamic> change) async {
    // Check for conflicts if server fetch is available
    if (onFetchServerVersion != null) {
      final entityType = change['entity_type'] as String?;
      final entityId = change['entity_id'] as String?;

      if (entityType != null && entityId != null) {
        final serverVersion = await onFetchServerVersion!(entityType, entityId);
        if (serverVersion != null) {
          final conflict = _detectConflict(change, serverVersion);
          if (conflict != null) {
            await _saveConflict(conflict);
            return ChangeSyncResult.conflict(
                change['change_id'], conflict);
          }
        }
      }
    }

    // Submit the change
    final response = await onSubmitChange!(change);
    if (response['success'] == true) {
      return ChangeSyncResult.success(change['change_id']);
    } else if (response['conflict'] == true) {
      final conflict = DataConflict(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        entityType: change['entity_type'] ?? 'unknown',
        entityId: change['entity_id'] ?? 'unknown',
        localData: change,
        serverData: Map<String, dynamic>.from(response['server_data'] ?? {}),
      );
      await _saveConflict(conflict);
      return ChangeSyncResult.conflict(change['change_id'], conflict);
    } else {
      return ChangeSyncResult.error(
          change['change_id'], response['error'] ?? 'Unknown error');
    }
  }

  /// Detect conflicts between local and server versions
  DataConflict? _detectConflict(
      Map<String, dynamic> local, Map<String, dynamic> server) {
    final localUpdated = DateTime.tryParse(local['updated_at'] ?? '');
    final serverUpdated = DateTime.tryParse(server['updated_at'] ?? '');

    if (localUpdated == null || serverUpdated == null) return null;

    // If server was updated after our last known version
    final localBaseUpdated = DateTime.tryParse(
        local['base_updated_at'] ?? local['created_at'] ?? '');

    if (localBaseUpdated != null && serverUpdated.isAfter(localBaseUpdated)) {
      // Check if there are actual data differences
      final localData = local['data'] ?? local;
      final serverData = server['data'] ?? server;

      if (_hasDataDifferences(localData, serverData)) {
        return DataConflict(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          entityType: local['entity_type'] ?? 'unknown',
          entityId: local['entity_id'] ?? 'unknown',
          localData: local,
          serverData: server,
        );
      }
    }

    return null;
  }

  bool _hasDataDifferences(Map<String, dynamic> a, Map<String, dynamic> b) {
    final skipKeys = {'updated_at', 'created_at', 'id', 'offline_id'};
    for (final key in a.keys) {
      if (skipKeys.contains(key)) continue;
      if (a[key] != b[key]) return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFLICT MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveConflict(DataConflict conflict) async {
    final conflicts = _getConflicts();
    conflicts[conflict.id] = conflict.toJson();
    await _offlineBox.put(_conflictsKey, jsonEncode(conflicts));
  }

  Map<String, dynamic> _getConflicts() {
    final data = _offlineBox.get(_conflictsKey);
    if (data == null || data.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (_) {
      return {};
    }
  }

  List<DataConflict> get unresolvedConflicts {
    final conflicts = _getConflicts();
    return conflicts.values
        .where((c) => c['resolved'] != true)
        .map((c) => DataConflict.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  List<DataConflict> get allConflicts {
    final conflicts = _getConflicts();
    return conflicts.values
        .map((c) => DataConflict.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  /// Resolve a conflict with the chosen strategy
  Future<void> resolveConflict(
    String conflictId,
    ConflictStrategy strategy, {
    Map<String, dynamic>? mergedData,
  }) async {
    final conflicts = _getConflicts();
    if (!conflicts.containsKey(conflictId)) return;

    final conflict = conflicts[conflictId];
    conflict['resolved'] = true;
    conflict['resolved_strategy'] = strategy.name;
    conflict['resolved_at'] = DateTime.now().toIso8601String();

    if (mergedData != null) {
      conflict['merged_data'] = mergedData;
    }

    // Apply the resolution
    final data = DataConflict.fromJson(Map<String, dynamic>.from(conflict));
    switch (strategy) {
      case ConflictStrategy.localWins:
        // Re-queue local version
        await addPendingChange(data.localData);
        break;
      case ConflictStrategy.serverWins:
        // Accept server version — no action needed
        break;
      case ConflictStrategy.merge:
        if (mergedData != null) {
          await addPendingChange({
            ...mergedData,
            'entity_type': data.entityType,
            'entity_id': data.entityId,
          });
        }
        break;
      case ConflictStrategy.manual:
        // User will handle manually
        break;
    }

    conflicts[conflictId] = conflict;
    await _offlineBox.put(_conflictsKey, jsonEncode(conflicts));
    _emitState();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTO SYNC
  // ═══════════════════════════════════════════════════════════════════════════

  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_autoSyncInterval, (_) {
      if (_isOnline && _pendingCount > 0) {
        syncWithConflictResolution();
      }
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SYNC HISTORY
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveSyncHistory(SyncBatchResult result) async {
    final history = _getSyncHistory();
    history.add({
      'timestamp': DateTime.now().toIso8601String(),
      'synced': result.synced,
      'conflicts': result.conflicts,
      'failed': result.failed,
      'retried': result.retried,
    });
    // Keep last 50 entries
    if (history.length > 50) {
      history.removeRange(0, history.length - 50);
    }
    await _offlineBox.put(_historyKey, jsonEncode(history));
  }

  List<Map<String, dynamic>> getSyncHistory() => _getSyncHistory();

  List<Map<String, dynamic>> _getSyncHistory() {
    final data = _offlineBox.get(_historyKey);
    if (data == null || data.isEmpty) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Clear all resolved conflicts
  Future<void> clearResolvedConflicts() async {
    final conflicts = _getConflicts();
    conflicts.removeWhere((_, v) => v['resolved'] == true);
    await _offlineBox.put(_conflictsKey, jsonEncode(conflicts));
  }

  /// Force sync a specific change
  Future<ChangeSyncResult> forceSync(String changeId) async {
    final pending = _getPendingChanges();
    final change = pending.firstWhere(
      (c) => c['change_id'] == changeId,
      orElse: () => {},
    );
    if (change.isEmpty) {
      return ChangeSyncResult.error(changeId, 'Change not found');
    }
    return _syncSingleChange(change);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _qualityTimer?.cancel();
    _stateController.close();
    _conflictController.close();
    _syncResultController.close();
  }
}

/// Result of a batch sync operation
class SyncBatchResult {
  int synced = 0;
  int conflicts = 0;
  int failed = 0;
  int retried = 0;
  List<String> errors = [];
  List<DataConflict> conflictList = [];
  bool isOffline = false;
  bool isEmpty = false;
  String? errorMessage;

  SyncBatchResult();
  SyncBatchResult.offline() : isOffline = true;
  SyncBatchResult.empty() : isEmpty = true;
  SyncBatchResult.error(String message) : errorMessage = message;

  int get total => synced + conflicts + failed + retried;
  bool get hasErrors => errors.isNotEmpty || errorMessage != null;
  bool get hasConflicts => conflicts > 0;

  String get summary =>
      'synced=$synced, conflicts=$conflicts, failed=$failed, retried=$retried';
}
