import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../security/encryption_service.dart';
import '../errors/app_exceptions.dart';

// Re-export all models from the pure-Dart models file
export 'sync_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PRODUCTION SYNC QUEUE
// ═══════════════════════════════════════════════════════════════════════════════

/// Production-grade sync queue with:
/// - Priority-based ordering (critical health data first)
/// - Exponential backoff retry (10s → 30s → 90s → 5min → 15min)
/// - Automatic dead-letter (failed) box after max retries
/// - Batch submission support
/// - Auto-cleanup of completed items older than 24h
/// - Full encryption at rest
class ProductionSyncQueue {
  static const String _queueBoxName = 'epi_sync_queue_v2';
  static const String _failedBoxName = 'epi_sync_failed';
  static const String _statsKey = 'queue_stats';

  final EncryptionService _encryption;
  final _uuid = const Uuid();

  Box<String>? _queueBox;
  Box<String>? _failedBox;

  final _countController = StreamController<QueueCounts>.broadcast();
  Stream<QueueCounts> get countsStream => _countController.stream;

  // Auto-cleanup timer
  Timer? _cleanupTimer;

  ProductionSyncQueue(this._encryption);

  /// Initialize Hive boxes. Must be called before any other method.
  Future<void> init() async {
    _queueBox = await Hive.openBox<String>(_queueBoxName);
    _failedBox = await Hive.openBox<String>(_failedBoxName);

    // ═══ FIX: Recover stuck items from previous crashes ═══
    await _recoverStuckItems();

    // Auto-cleanup every hour: remove completed items older than 24h
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) => _autoCleanup());

    // Emit initial counts
    _emitCounts();
  }

  /// Reset items stuck in `syncing` state back to `pending`.
  /// These are orphaned from a previous app crash during sync.
  Future<void> _recoverStuckItems() async {
    if (_queueBox == null || !_queueBox!.isOpen) return;
    int recovered = 0;
    for (final key in _queueBox!.keys) {
      final raw = _queueBox!.get(key);
      if (raw == null) continue;
      try {
        final entry = SyncQueueEntry.fromJson(
          Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(raw))),
        );
        if (entry.status == QueueItemStatus.syncing) {
          // Reset to pending so it gets picked up on next sync
          final resetEntry = entry.copyWith(
            status: QueueItemStatus.pending,
            lastAttemptAt: null,
          );
          await _saveEntry(resetEntry);
          recovered++;
        }
      } catch (_) {
        // Corrupted entry — leave for auto-cleanup
      }
    }
    if (recovered > 0 && kDebugMode) {
      print('[SyncQueue] Recovered $recovered stuck syncing items');
    }
  }

  // ─── ENQUEUE ─────────────────────────────────────────────────────────────

  /// Add a new item to the sync queue. Returns the entry ID.
  Future<String> enqueue({
    required String type,
    required Map<String, dynamic> payload,
    SyncPriority priority = SyncPriority.normal,
    Map<String, dynamic>? metadata,
  }) async {
    final entry = SyncQueueEntry(
      id: _uuid.v4(),
      type: type,
      payload: payload,
      priority: priority,
      status: QueueItemStatus.pending,
      createdAt: DateTime.now(),
      metadata: metadata ?? {},
    );

    await _saveEntry(entry);
    _emitCounts();

    if (kDebugMode) print('[SyncQueue] Enqueued: ${entry.id} (type=$type, priority=${priority.name})');
    return entry.id;
  }

  // ─── DEQUEUE (priority-ordered) ──────────────────────────────────────────

  /// Get all pending/retrying items sorted by priority (highest first),
  /// then by creation time (oldest first within same priority).
  List<SyncQueueEntry> getReadyItems() {
    final entries = _getAllEntries();
    return entries
        .where((e) =>
            (e.status == QueueItemStatus.pending || e.status == QueueItemStatus.retrying) &&
            e.isReadyForRetry)
        .toList()
      ..sort((a, b) {
        // Higher priority first
        final priorityCompare = b.priority.value.compareTo(a.priority.value);
        if (priorityCompare != 0) return priorityCompare;
        // Older items first within same priority
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  /// Get items ready for batch submission (max [batchSize] items).
  List<SyncQueueEntry> getBatch(int batchSize) {
    return getReadyItems().take(batchSize).toList();
  }

  // ─── STATUS UPDATES ──────────────────────────────────────────────────────

  /// Mark an item as currently being synced.
  Future<void> markSyncing(String id) async {
    final entry = _getEntry(id);
    if (entry == null) return;
    await _saveEntry(entry.copyWith(
      status: QueueItemStatus.syncing,
      lastAttemptAt: DateTime.now(),
    ));
  }

  /// Mark an item as successfully synced. Removes it from the queue.
  Future<void> markCompleted(String id) async {
    await _deleteEntry(id);
    _emitCounts();
    if (kDebugMode) print('[SyncQueue] Completed: $id');
  }

  /// Mark an item as failed. Increments retry count.
  /// If max retries exceeded, moves to the failed (dead-letter) box.
  Future<void> markFailed(String id, String error) async {
    final entry = _getEntry(id);
    if (entry == null) return;

    final newRetryCount = entry.retryCount + 1;

    if (newRetryCount >= SyncQueueEntry.maxRetries) {
      // Move to dead-letter (failed) box
      final failedEntry = entry.copyWith(
        status: QueueItemStatus.failed,
        retryCount: newRetryCount,
        lastError: error,
        lastAttemptAt: DateTime.now(),
      );
      await _saveFailedEntry(failedEntry);
      await _deleteEntry(id);
      if (kDebugMode) print('[SyncQueue] Moved to failed box: $id (retries=$newRetryCount)');
    } else {
      // Update for retry with backoff
      final retryEntry = entry.copyWith(
        status: QueueItemStatus.retrying,
        retryCount: newRetryCount,
        lastError: error,
        lastAttemptAt: DateTime.now(),
      );
      await _saveEntry(retryEntry);
      if (kDebugMode) {
        print('[SyncQueue] Retry $newRetryCount/${SyncQueueEntry.maxRetries} for $id '
              '(next retry in ${retryEntry.nextRetryDelay.inSeconds}s)');
      }
    }
    _emitCounts();
  }

  // ─── FAILED (DEAD-LETTER) QUEUE ─────────────────────────────────────────

  /// Get all permanently failed items for manual review.
  List<SyncQueueEntry> getFailedItems() {
    if (_failedBox == null || !_failedBox!.isOpen) return [];
    return _failedBox!.values.map((raw) {
      try {
        return SyncQueueEntry.fromJson(
          Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(raw))),
        );
      } catch (_) {
        return null;
      }
    }).whereType<SyncQueueEntry>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Retry a specific failed item (reset retry count, move back to queue).
  Future<void> retryFailed(String id) async {
    if (_failedBox == null) return;
    final raw = _failedBox!.get(id);
    if (raw == null) return;

    try {
      final entry = SyncQueueEntry.fromJson(
        Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(raw))),
      );
      final resetEntry = entry.copyWith(
        status: QueueItemStatus.pending,
        retryCount: 0,
        lastError: null,
        lastAttemptAt: null,
      );
      await _saveEntry(resetEntry);
      await _failedBox!.delete(id);
      _emitCounts();
    } catch (_) {}
  }

  /// Retry ALL failed items at once.
  Future<void> retryAllFailed() async {
    final failed = getFailedItems();
    for (final entry in failed) {
      await retryFailed(entry.id);
    }
  }

  /// Permanently delete a failed item.
  Future<void> deleteFailed(String id) async {
    await _failedBox?.delete(id);
    _emitCounts();
  }

  // ─── COUNTS & STATS ─────────────────────────────────────────────────────

  QueueCounts getCounts() {
    final entries = _getAllEntries();
    final pending = entries.where((e) => e.status == QueueItemStatus.pending).length;
    final retrying = entries.where((e) => e.status == QueueItemStatus.retrying).length;
    final syncing = entries.where((e) => e.status == QueueItemStatus.syncing).length;
    final failed = getFailedItems().length;

    return QueueCounts(
      pending: pending,
      retrying: retrying,
      syncing: syncing,
      failed: failed,
      total: pending + retrying + syncing,
    );
  }

  int get pendingCount => getCounts().total;
  int get failedCount => getCounts().failed;

  // ─── CLEANUP ─────────────────────────────────────────────────────────────

  /// Remove completed items older than [maxAge] (default: 24 hours).
  /// Also cleans up corrupted entries.
  Future<void> _autoCleanup() async {
    if (_queueBox == null) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    int cleaned = 0;

    final keysToDelete = <String>[];
    for (final key in _queueBox!.keys) {
      final raw = _queueBox!.get(key);
      if (raw == null) continue;
      try {
        final entry = SyncQueueEntry.fromJson(
          Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(raw))),
        );
        // Remove old completed items
        if (entry.status == QueueItemStatus.completed && entry.createdAt.isBefore(cutoff)) {
          keysToDelete.add(key as String);
        }
      } catch (_) {
        // Remove corrupted entries
        keysToDelete.add(key as String);
      }
    }

    for (final key in keysToDelete) {
      await _queueBox!.delete(key);
      cleaned++;
    }

    if (cleaned > 0 && kDebugMode) {
      print('[SyncQueue] Auto-cleanup removed $cleaned old entries');
    }
  }

  /// Clear the entire queue (use with caution).
  Future<void> clearAll() async {
    await _queueBox?.clear();
    _emitCounts();
  }

  /// Clear the failed box.
  Future<void> clearFailed() async {
    await _failedBox?.clear();
    _emitCounts();
  }

  // ─── PRIVATE HELPERS ─────────────────────────────────────────────────────

  Box<String> get _safeQueueBox {
    final b = _queueBox;
    if (b == null || !b.isOpen) {
      throw StateError('ProductionSyncQueue not initialized. Call init() first.');
    }
    return b;
  }

  Future<void> _saveEntry(SyncQueueEntry entry) async {
    final encrypted = _encryption.encrypt(jsonEncode(entry.toJson()));
    await _safeQueueBox.put(entry.id, encrypted);
  }

  Future<void> _deleteEntry(String id) async {
    await _safeQueueBox.delete(id);
  }

  SyncQueueEntry? _getEntry(String id) {
    final raw = _safeQueueBox.get(id);
    if (raw == null) return null;
    try {
      return SyncQueueEntry.fromJson(
        Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(raw))),
      );
    } catch (_) {
      return null;
    }
  }

  List<SyncQueueEntry> _getAllEntries() {
    return _safeQueueBox.values.map((raw) {
      try {
        return SyncQueueEntry.fromJson(
          Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(raw))),
        );
      } catch (_) {
        return null;
      }
    }).whereType<SyncQueueEntry>().toList();
  }

  Future<void> _saveFailedEntry(SyncQueueEntry entry) async {
    if (_failedBox == null || !_failedBox!.isOpen) return;
    final encrypted = _encryption.encrypt(jsonEncode(entry.toJson()));
    await _failedBox!.put(entry.id, encrypted);
  }

  void _emitCounts() {
    if (!_countController.isClosed) {
      _countController.add(getCounts());
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _countController.close();
  }
}
