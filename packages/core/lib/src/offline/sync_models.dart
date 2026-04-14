/// Pure Dart sync models — no platform dependencies (no Hive, no Flutter engine).
/// Safe to import in unit tests.
library;

import 'dart:convert';
import 'dart:math';

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

/// Priority levels for sync queue items.
/// Higher priority items are synced first.
enum SyncPriority {
  critical(100), // Form submissions with health data
  high(75),      // Shortage reports
  normal(50),    // Profile updates
  low(25);       // Analytics, logs

  const SyncPriority(this.value);
  final int value;
}

/// Status of a queue item through its lifecycle.
enum QueueItemStatus {
  pending,    // Waiting to be synced
  syncing,    // Currently being sent
  retrying,   // Failed, waiting for retry
  failed,     // Exceeded max retries, moved to failed box
  completed;  // Successfully synced
}

/// Conflict resolution strategies.
enum ConflictStrategy { localWins, serverWins, merge, manual, smartMerge, manualReview }

/// Network state for UI display.
enum NetworkStatus { online, offline, syncing }

/// Sync result status enum
enum OfflineSyncStatus { success, conflict, error, duplicate }

// ═══════════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════════

/// A single item in the sync queue with full metadata.
class SyncQueueEntry {
  final String id;
  final String type; // 'form_submission', 'shortage', 'profile_update', etc.
  final Map<String, dynamic> payload;
  final SyncPriority priority;
  final QueueItemStatus status;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final int retryCount;
  final String? lastError;
  final Map<String, dynamic> metadata;

  // Exponential backoff delays: 10s, 30s, 90s, 5min, 15min
  static const List<int> _backoffSeconds = [10, 30, 90, 300, 900];
  static const int maxRetries = 5;

  const SyncQueueEntry({
    required this.id,
    required this.type,
    required this.payload,
    this.priority = SyncPriority.normal,
    this.status = QueueItemStatus.pending,
    required this.createdAt,
    this.lastAttemptAt,
    this.retryCount = 0,
    this.lastError,
    this.metadata = const {},
  });

  /// Whether this item is ready to be retried (backoff has elapsed).
  bool get isReadyForRetry {
    if (status != QueueItemStatus.retrying) return status == QueueItemStatus.pending;
    if (lastAttemptAt == null) return true;
    final backoffIndex = min(retryCount, _backoffSeconds.length - 1);
    final backoffDuration = Duration(seconds: _backoffSeconds[backoffIndex]);
    return DateTime.now().difference(lastAttemptAt!) >= backoffDuration;
  }

  /// Whether this item has permanently failed.
  bool get hasFailed => status == QueueItemStatus.failed || retryCount >= maxRetries;

  Duration get nextRetryDelay {
    final backoffIndex = min(retryCount, _backoffSeconds.length - 1);
    return Duration(seconds: _backoffSeconds[backoffIndex]);
  }

  SyncQueueEntry copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? payload,
    SyncPriority? priority,
    QueueItemStatus? status,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    int? retryCount,
    String? lastError,
    Map<String, dynamic>? metadata,
  }) {
    return SyncQueueEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for Hive storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'priority': priority.name,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'last_attempt_at': lastAttemptAt?.toIso8601String(),
        'retry_count': retryCount,
        'last_error': lastError,
        'metadata': metadata,
      };

  /// Restore from JSON.
  factory SyncQueueEntry.fromJson(Map<String, dynamic> json) {
    return SyncQueueEntry(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      priority: SyncPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => SyncPriority.normal,
      ),
      status: QueueItemStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => QueueItemStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastAttemptAt: json['last_attempt_at'] != null
          ? DateTime.tryParse(json['last_attempt_at'] as String)
          : null,
      retryCount: json['retry_count'] as int? ?? 0,
      lastError: json['last_error'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  @override
  String toString() =>
      'SyncQueueEntry($id, type=$type, priority=${priority.name}, status=${status.name}, retries=$retryCount)';
}

/// Result of a single item sync attempt.
class SyncItemResult {
  final String entryId;
  final bool success;
  final bool isDuplicate;
  final bool hasConflict;
  final Map<String, dynamic>? serverData;
  final String? error;

  const SyncItemResult._({
    required this.entryId,
    required this.success,
    this.isDuplicate = false,
    this.hasConflict = false,
    this.serverData,
    this.error,
  });

  factory SyncItemResult.ok(String id, [Map<String, dynamic>? data]) =>
      SyncItemResult._(entryId: id, success: true, serverData: data);

  factory SyncItemResult.duplicate(String id, [Map<String, dynamic>? data]) =>
      SyncItemResult._(entryId: id, success: true, isDuplicate: true, serverData: data);

  factory SyncItemResult.conflict(String id, Map<String, dynamic> serverData) =>
      SyncItemResult._(entryId: id, success: false, hasConflict: true, serverData: serverData);

  factory SyncItemResult.error(String id, String error) =>
      SyncItemResult._(entryId: id, success: false, error: error);

  @override
  String toString() =>
      'SyncItemResult($entryId: ${success ? "ok" : "error"}${isDuplicate ? " [dup]" : ""}${hasConflict ? " [conflict]" : ""})';
}

/// Summary of a full sync cycle.
class SyncCycleSummary {
  final int totalItems;
  final int synced;
  final int duplicates;
  final int conflicts;
  final int failed;
  final int retried;
  final List<String> errors;
  final DateTime completedAt;

  SyncCycleSummary({
    this.totalItems = 0,
    this.synced = 0,
    this.duplicates = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.retried = 0,
    this.errors = const [],
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();

  bool get allSuccessful => failed == 0 && conflicts == 0;
  bool get hasErrors => failed > 0 || errors.isNotEmpty;

  @override
  String toString() =>
      'SyncCycle($totalItems items: $synced ok, $duplicates dup, $conflicts conflict, $failed fail, $retried retry)';
}

/// Snapshot of queue counts for UI display.
class QueueCounts {
  final int pending;
  final int retrying;
  final int syncing;
  final int failed;

  const QueueCounts({
    this.pending = 0,
    this.retrying = 0,
    this.syncing = 0,
    this.failed = 0,
  });

  int get total => pending + retrying + syncing;
  bool get isEmpty => total == 0;
  bool get hasActivity => syncing > 0;

  @override
  String toString() => 'QueueCounts(pending=$pending, retrying=$retrying, syncing=$syncing, failed=$failed)';
}

/// Result of a sync attempt (legacy offline manager).
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

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT RESOLUTION
// ═══════════════════════════════════════════════════════════════════════════════

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
      case ConflictStrategy.manual:
        // Cannot auto-resolve; return local as placeholder
        return conflict.localData;

      case ConflictStrategy.merge:
        return _smartMerge(conflict.localData, conflict.serverData);
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
// NETWORK SNAPSHOT
// ═══════════════════════════════════════════════════════════════════════════════

/// Network state snapshot for UI display.
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
