import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../config/supabase_config.dart';
import '../offline/offline_manager.dart';
import '../offline/offline_data_cache.dart';

/// Manages background synchronization of offline data.
/// Handles batch syncing, conflict resolution, retry with backoff, and dedup.
class SyncService {
  final ApiClient _api;
  final OfflineManager _offline;
  OfflineDataCache? _dataCache;
  Timer? _syncTimer;
  DateTime? _syncLockTime;
  bool _isSyncing = false;
  static const int _maxBatchSize = 50;
  static const int _maxRetries = 5;
  static const int _staleLockSeconds = 180; // 3 دقائق قبل إعادة ضبط القفل

  /// Completer لمنع Race Condition — كل sync ينتظر اللي قبله
  Completer<SyncCycleResult>? _activeCompleter;

  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncState => _syncStateController.stream;
  SyncState _currentState = const SyncState();
  SyncState get currentState => _currentState;

  /// Debounce لمنع إطلاق مزامنتين متتاليتين من reconnect + timer
  DateTime? _lastSyncAttempt;
  static const _debounceWindow = Duration(seconds: 10);

  SyncService(this._api, this._offline) {
    _offline.connectivityStream.listen((isOnline) {
      if (isOnline && _offline.pendingCount > 0) {
        _attemptSync('reconnect');
      }
    });
  }

  /// Set the data cache for manual refresh operations.
  void setDataCache(OfflineDataCache cache) {
    _dataCache = cache;
  }

  /// ═══ MANUAL: Force refresh all data from server ═══
  /// Called when user taps "مزامنة تكوين" in the drawer.
  /// Clears all cached data so next provider fetch gets fresh data from server.
  /// Submissions in the sync queue are NOT affected.
  Future<void> forceRefreshAll() async {
    try {
      final cache = _dataCache;
      if (cache != null) {
        await cache.invalidateAll();
        if (kDebugMode)
          print(
              '[SyncService] All caches cleared — next fetch will get fresh data');
      }
    } catch (e) {
      if (kDebugMode) print('[SyncService] forceRefreshAll error: $e');
      rethrow;
    }
  }

  /// بدء المزامنة التلقائية
  void startAutoSync() {
    _syncTimer?.cancel();
    // ═══ FIX: فترة أطول (3 دقائق) بدل 2 — تقليل الضغط على السيرفر ═══
    _syncTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _attemptSync('timer'),
    );
    // محاولة أولى بعد 5 ثوانٍ
    Timer(const Duration(seconds: 5), () => _attemptSync('initial'));
    if (kDebugMode) print('[SyncService] Auto-sync started (every 3 min)');
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    if (kDebugMode) print('[SyncService] Auto-sync stopped');
  }

  /// محاولة مزامنة مع debouncing
  Future<void> _attemptSync(String trigger) async {
    // ═══ FIX: Debounce — تجاهل المحاولات المتكررة خلال 10 ثوانٍ ═══
    final now = DateTime.now();
    if (_lastSyncAttempt != null &&
        now.difference(_lastSyncAttempt!).compareTo(_debounceWindow) < 0) {
      if (kDebugMode) print('[SyncService] Debounced ($trigger)');
      return;
    }
    _lastSyncAttempt = now;

    if (_isSyncing) {
      // ═══ FIX: إذا في sync شغال، ننتظره بدل ما نتجاوزه ═══
      if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
        if (kDebugMode)
          print('[SyncService] Waiting for active sync ($trigger)');
        await _activeCompleter!.future;
      }
      return;
    }
    if (!_offline.isInitialized) return;

    final pending = _offline.pendingCount;
    if (pending == 0) return;

    if (kDebugMode)
      print('[SyncService] Triggered by $trigger ($pending items)');
    await sync();
  }

  /// تنفيذ دورة مزامنة كاملة
  Future<SyncCycleResult> sync() async {
    // ═══ FIX: إذا sync شغال، نرجع نفس الـ Completer ═══
    if (_isSyncing) {
      final lockAge = _syncLockTime != null
          ? DateTime.now().difference(_syncLockTime!).inSeconds
          : 0;

      if (lockAge > _staleLockSeconds) {
        if (kDebugMode)
          print('[SyncService] Stale lock (${lockAge}s), resetting');
        _isSyncing = false;
        _activeCompleter?.complete(SyncCycleResult.empty());
        _activeCompleter = null;
      } else if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
        // نرجع نفس الـ result حق sync الجاري
        return _activeCompleter!.future;
      } else {
        return SyncCycleResult.empty();
      }
    }

    if (!_offline.isInitialized) return SyncCycleResult.empty();

    final pendingItems = await _offline.getPendingItems();
    if (pendingItems.isEmpty) return SyncCycleResult.empty();

    // ═══ FIX: Deduplication — نزيل العناصر المكررة ═══
    final seen = <String>{};
    final uniqueItems = <Map<String, dynamic>>[];
    for (final item in pendingItems) {
      final id = item['offline_id'] as String? ?? '';
      if (id.isNotEmpty && seen.add(id)) {
        uniqueItems.add(item);
      }
    }

    if (uniqueItems.isEmpty) return SyncCycleResult.empty();

    _isSyncing = true;
    _syncLockTime = DateTime.now();
    _activeCompleter = Completer<SyncCycleResult>();
    _updateState(isSyncing: true);

    final result = SyncCycleResult();

    try {
      // ═══ معالجة العناصر دفعات ═══
      for (int offset = 0;
          offset < uniqueItems.length;
          offset += _maxBatchSize) {
        final batchEnd = (offset + _maxBatchSize).clamp(0, uniqueItems.length);
        final batch = uniqueItems.sublist(offset, batchEnd);

        if (kDebugMode)
          print(
              '[SyncService] Batch: ${batch.length} items ($offset/${uniqueItems.length})');

        // ═══ FIX: تصفية العناصر التي تجاوزت الحد الأقصى ═══
        final toRetry = <Map<String, dynamic>>[];
        final toArchive = <Map<String, dynamic>>[];

        for (final item in batch) {
          final retryCount = (item['retry_count'] ?? 0) as int;
          if (retryCount >= _maxRetries) {
            toArchive.add(item);
          } else {
            toRetry.add(item);
          }
        }

        // أرشف العناصر الفاشلة نهائياً (إزالة من الطابور + تسجيل في السجل)
        for (final item in toArchive) {
          final offlineId = item['offline_id'] as String? ?? '';
          await _offline.removeFromQueue(offlineId);
          if (kDebugMode)
            print('[SyncService] Archived failed item: $offlineId');
          result.archived++;
          result.errors.add(SyncError(
            offlineId: offlineId,
            error: 'Max retries ($_maxRetries) exceeded — removed from queue',
          ));
        }

        if (toRetry.isEmpty) continue;

        try {
          // تجهيز البيانات
          final items = toRetry.map((item) {
            final payload = Map<String, dynamic>.from(item);
            payload.remove('_syncing');
            payload.remove('_recovered');
            return payload;
          }).toList();

          final response = await _api.callFunction(
            SupabaseConfig.fnSyncOffline,
            {'items': items},
          ).timeout(
            const Duration(seconds: 90), // ═══ مهلة أطول ═══
            onTimeout: () {
              if (kDebugMode) print('[SyncService] Timeout');
              throw TimeoutException('Batch sync timed out');
            },
          );

          final serverResults = (response['results'] as List?) ?? [];
          final serverErrors = (response['errors'] as List?) ?? [];

          for (final item in toRetry) {
            final offlineId = item['offline_id'] as String? ?? '';

            final match = serverResults.cast<Map<String, dynamic>>().firstWhere(
                  (r) => r['offline_id'] == offlineId,
                  orElse: () => <String, dynamic>{},
                );

            if (match.isNotEmpty) {
              final status = match['status'] as String? ?? 'error';
              switch (status) {
                case 'synced':
                  await _offline.removeFromQueue(offlineId);
                  result.synced++;
                case 'duplicate':
                  await _offline.removeFromQueue(offlineId);
                  result.duplicates++;
                case 'conflict':
                  await _offline.saveConflict(item, match);
                  await _offline.removeFromQueue(offlineId);
                  result.conflicts++;
                  result.conflictDetails
                      .add(OfflineSyncResult.conflict(offlineId, match));
                default:
                  // ═══ FIX: backoff تدريجي ═══
                  final retryCount = (item['retry_count'] ?? 0) as int;
                  final backoffSeconds = _calculateBackoff(retryCount);
                  item['retry_count'] = retryCount + 1;
                  item['last_retry_at'] = DateTime.now().toIso8601String();
                  item['next_retry_at'] = DateTime.now()
                      .add(Duration(seconds: backoffSeconds))
                      .toIso8601String();
                  result.failed++;
                  result.errors.add(SyncError(
                    offlineId: offlineId,
                    error: match['error'] ??
                        'Unknown error (retry ${retryCount + 1}/$_maxRetries in ${backoffSeconds}s)',
                  ));
              }
            } else {
              final errMatch =
                  serverErrors.cast<Map<String, dynamic>>().firstWhere(
                        (e) => e['offline_id'] == offlineId,
                        orElse: () => <String, dynamic>{},
                      );
              final retryCount = (item['retry_count'] ?? 0) as int;
              final backoffSeconds = _calculateBackoff(retryCount);
              item['retry_count'] = retryCount + 1;
              item['last_retry_at'] = DateTime.now().toIso8601String();
              item['next_retry_at'] = DateTime.now()
                  .add(Duration(seconds: backoffSeconds))
                  .toIso8601String();
              result.failed++;
              result.errors.add(SyncError(
                offlineId: offlineId,
                error: errMatch['error'] ??
                    'No response (retry ${retryCount + 1}/$_maxRetries)',
              ));
            }
          }
        } on TimeoutException {
          _applyBackoffToBatch(toRetry, result, 'Timeout');
        } catch (e) {
          if (kDebugMode) print('[SyncService] Batch error: $e');
          _applyBackoffToBatch(toRetry, result, e.toString());
        }
      }

      if (result.synced > 0 || result.duplicates > 0) {
        _offline.updateConnectivity(true);
      }
    } catch (e) {
      if (kDebugMode) print('[SyncService] Cycle error: $e');
      result.errors.add(SyncError(error: e.toString()));

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
      _syncLockTime = null;
      _updateState(
        isSyncing: false,
        lastSync: DateTime.now(),
        pendingCount: _offline.pendingCount,
      );
      if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
        _activeCompleter!.complete(result);
      }
      _activeCompleter = null;
    }

    if (kDebugMode) {
      print('[SyncService] Done: +${result.synced} dup=${result.duplicates} '
          'conf=${result.conflicts} fail=${result.failed} archive=${result.archived} '
          'remain=${_offline.pendingCount}');
    }

    return result;
  }

  /// ═══ Backoff أسي: 10s → 20s → 40s → 80s → 160s ═══
  int _calculateBackoff(int retryCount) {
    return (10 * pow(2, retryCount)).toInt().clamp(10, 600);
  }

  /// تطبيق backoff على دفعة كاملة
  void _applyBackoffToBatch(
    List<Map<String, dynamic>> batch,
    SyncCycleResult result,
    String error,
  ) {
    for (final item in batch) {
      final retryCount = (item['retry_count'] ?? 0) as int;
      final backoffSeconds = _calculateBackoff(retryCount);
      item['retry_count'] = retryCount + 1;
      item['last_retry_at'] = DateTime.now().toIso8601String();
      item['next_retry_at'] = DateTime.now()
          .add(Duration(seconds: backoffSeconds))
          .toIso8601String();
      result.failed++;
      result.errors.add(SyncError(
        offlineId: item['offline_id'] as String? ?? '',
        error: '$error (retry ${retryCount + 1}/$_maxRetries)',
      ));
    }
  }

  List<Map<String, dynamic>> getConflicts() {
    return _offline.getUnresolvedConflicts();
  }

  Future<void> resolveConflict(String offlineId,
      {bool useLocal = false}) async {
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

/// حالة خدمة المزامنة
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

/// نتيجة دورة مزامنة
class SyncCycleResult {
  int synced = 0;
  int duplicates = 0;
  int conflicts = 0;
  int failed = 0;
  int archived = 0;
  List<SyncError> errors = [];
  List<OfflineSyncResult> conflictDetails = [];

  SyncCycleResult();
  factory SyncCycleResult.empty() => SyncCycleResult();

  bool get hasErrors => errors.isNotEmpty;
  bool get hasConflicts => conflicts > 0;
  int get total => synced + duplicates + conflicts + failed + archived;

  @override
  String toString() =>
      'SyncCycleResult(synced=$synced, dup=$duplicates, conflict=$conflicts, '
      'failed=$failed, archived=$archived)';
}

/// خطأ مزامنة فردي
class SyncError {
  final String? offlineId;
  final String error;

  SyncError({this.offlineId, required this.error});

  @override
  String toString() => 'SyncError(${offlineId ?? "?"}: $error)';
}
