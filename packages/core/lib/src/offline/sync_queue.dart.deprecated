import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../security/encryption_service.dart';

/// Persistent sync queue for offline form submissions.
/// Items are stored encrypted in Hive and retried when connectivity is restored.
class SyncQueue {
  static const String _boxName = 'epi_sync_queue';
  static const int _maxRetries = AppConfig.maxRetries;

  late Box<String> _box;
  final EncryptionService _encryption;
  final _uuid = const Uuid();

  final _pendingController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingController.stream;

  SyncQueue(this._encryption);

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  /// Add a new item to the sync queue. Returns the generated offlineId.
  Future<String> enqueue({
    required String type, // 'form_submission' | 'shortage' | etc.
    required Map<String, dynamic> payload,
    Map<String, dynamic>? metadata,
  }) async {
    final offlineId = _uuid.v4();
    final item = SyncQueueItem(
      id: offlineId,
      type: type,
      payload: payload,
      metadata: metadata ?? {},
      createdAt: DateTime.now(),
      retryCount: 0,
      status: SyncStatus.pending,
    );

    await _box.put(offlineId, _encryption.encrypt(jsonEncode(item.toJson())));
    _notifyCount();
    return offlineId;
  }

  /// Get all pending items ordered by creation time
  List<SyncQueueItem> getPending() {
    final items = _getAllItems();
    return items
        .where((i) =>
            i.status == SyncStatus.pending || i.status == SyncStatus.retrying)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get all items (including failed)
  List<SyncQueueItem> getAll() => _getAllItems();

  /// Mark an item as synced (removes it from queue)
  Future<void> markSynced(String id) async {
    await _box.delete(id);
    _notifyCount();
  }

  /// Mark an item as failed and increment retry count
  Future<void> markFailed(String id, String error) async {
    final item = _getItem(id);
    if (item == null) return;

    final updated = item.copyWith(
      retryCount: item.retryCount + 1,
      lastError: error,
      lastAttempt: DateTime.now(),
      status: item.retryCount + 1 >= _maxRetries
          ? SyncStatus.failed
          : SyncStatus.retrying,
    );

    await _box.put(id, _encryption.encrypt(jsonEncode(updated.toJson())));
    _notifyCount();
  }

  /// Mark item as in-progress
  Future<void> markInProgress(String id) async {
    final item = _getItem(id);
    if (item == null) return;

    final updated = item.copyWith(
      status: SyncStatus.inProgress,
      lastAttempt: DateTime.now(),
    );
    await _box.put(id, _encryption.encrypt(jsonEncode(updated.toJson())));
  }

  /// Reset failed items back to pending for retry
  Future<void> resetFailed() async {
    final failed = _getAllItems().where((i) => i.status == SyncStatus.failed);
    for (final item in failed) {
      final reset = item.copyWith(status: SyncStatus.pending, retryCount: 0);
      await _box.put(item.id, _encryption.encrypt(jsonEncode(reset.toJson())));
    }
    _notifyCount();
  }

  /// Remove a specific item
  Future<void> remove(String id) async {
    await _box.delete(id);
    _notifyCount();
  }

  /// Clear all queue items
  Future<void> clear() async {
    await _box.clear();
    _notifyCount();
  }

  int get pendingCount =>
      _getAllItems().where((i) => i.status != SyncStatus.failed).length;

  int get failedCount =>
      _getAllItems().where((i) => i.status == SyncStatus.failed).length;

  // ─── Private ──────────────────────────────────────────────────────────────

  List<SyncQueueItem> _getAllItems() {
    return _box.values.map((raw) {
      try {
        return SyncQueueItem.fromJson(
          Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(raw))),
        );
      } catch (_) {
        return null;
      }
    }).whereType<SyncQueueItem>().toList();
  }

  SyncQueueItem? _getItem(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    try {
      return SyncQueueItem.fromJson(
        Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(raw))),
      );
    } catch (_) {
      return null;
    }
  }

  void _notifyCount() {
    _pendingController.add(pendingCount);
  }

  void dispose() {
    _pendingController.close();
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

enum SyncStatus { pending, inProgress, retrying, failed, synced }

class SyncQueueItem {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final DateTime? lastAttempt;
  final SyncStatus status;

  const SyncQueueItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.metadata,
    required this.createdAt,
    required this.retryCount,
    required this.status,
    this.lastError,
    this.lastAttempt,
  });

  SyncQueueItem copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
    DateTime? lastAttempt,
    SyncStatus? status,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'last_error': lastError,
        'last_attempt': lastAttempt?.toIso8601String(),
        'status': status.name,
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        id: json['id'] as String,
        type: json['type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
        createdAt: DateTime.parse(json['created_at'] as String),
        retryCount: json['retry_count'] as int? ?? 0,
        lastError: json['last_error'] as String?,
        lastAttempt: json['last_attempt'] != null
            ? DateTime.tryParse(json['last_attempt'] as String)
            : null,
        status: SyncStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => SyncStatus.pending,
        ),
      );
}
