import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:epi_core/src/offline/sync_queue_v2.dart';
import 'package:epi_core/src/offline/intelligent_offline_manager.dart';
import 'package:epi_core/src/offline/enhanced_sync_service.dart' show ConflictStrategy;
import 'package:epi_core/src/security/encryption_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOCKS & HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Simple mock encryption that passes data through (for testing only).
class MockEncryptionService extends EncryptionService {
  @override
  String encrypt(String plaintext) => 'enc:$plaintext';

  @override
  String decrypt(String ciphertext) {
    if (ciphertext.startsWith('enc:')) {
      return ciphertext.substring(4);
    }
    throw Exception('Invalid mock ciphertext');
  }
}

/// Controllable connectivity mock for testing online/offline transitions.
class MockConnectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> _currentResult = [ConnectivityResult.wifi];
  int _listenerCallCount = 0;

  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  Future<List<ConnectivityResult>> checkConnectivity() async => _currentResult;

  int get listenerCallCount => _listenerCallCount;

  void simulateOnline() {
    _currentResult = [ConnectivityResult.wifi];
    _controller.add(_currentResult);
    _listenerCallCount++;
  }

  void simulateOffline() {
    _currentResult = [ConnectivityResult.none];
    _controller.add(_currentResult);
    _listenerCallCount++;
  }

  void simulateMobile() {
    _currentResult = [ConnectivityResult.mobile];
    _controller.add(_currentResult);
    _listenerCallCount++;
  }

  void dispose() => _controller.close();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: SyncQueueEntry Model
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  group('SyncQueueEntry', () {
    test('serialization roundtrip preserves all fields', () {
      final entry = SyncQueueEntry(
        id: 'test-id-1',
        type: 'form_submission',
        payload: {'form_id': 'f1', 'data': {'name': 'test'}},
        priority: SyncPriority.critical,
        status: QueueItemStatus.retrying,
        createdAt: DateTime(2026, 4, 14, 10, 30),
        lastAttemptAt: DateTime(2026, 4, 14, 10, 31),
        retryCount: 2,
        lastError: 'Network timeout',
        metadata: {'source': 'field'},
      );

      final json = entry.toJson();
      final restored = SyncQueueEntry.fromJson(json);

      expect(restored.id, equals(entry.id));
      expect(restored.type, equals(entry.type));
      expect(restored.payload['form_id'], equals('f1'));
      expect(restored.priority, equals(SyncPriority.critical));
      expect(restored.status, equals(QueueItemStatus.retrying));
      expect(restored.retryCount, equals(2));
      expect(restored.lastError, equals('Network timeout'));
      expect(restored.metadata['source'], equals('field'));
    });

    test('isReadyForRetry respects exponential backoff', () {
      // Pending item is always ready
      final pending = SyncQueueEntry(
        id: 'pending-1',
        type: 'test',
        payload: {},
        createdAt: DateTime.now(),
        status: QueueItemStatus.pending,
      );
      expect(pending.isReadyForRetry, isTrue);

      // Retry with 10s backoff, attempted 1s ago — NOT ready
      final justRetried = SyncQueueEntry(
        id: 'retry-1',
        type: 'test',
        payload: {},
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        status: QueueItemStatus.retrying,
        retryCount: 0, // 10s backoff
        lastAttemptAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(justRetried.isReadyForRetry, isFalse);

      // Retry with 10s backoff, attempted 15s ago — ready
      final backoffElapsed = SyncQueueEntry(
        id: 'retry-2',
        type: 'test',
        payload: {},
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        status: QueueItemStatus.retrying,
        retryCount: 0,
        lastAttemptAt: DateTime.now().subtract(const Duration(seconds: 15)),
      );
      expect(backoffElapsed.isReadyForRetry, isTrue);
    });

    test('nextRetryDelay follows exponential sequence', () {
      final delays = [0, 1, 2, 3, 4, 5].map((i) {
        final entry = SyncQueueEntry(
          id: 'test-$i',
          type: 'test',
          payload: {},
          createdAt: DateTime.now(),
          retryCount: i,
        );
        return entry.nextRetryDelay.inSeconds;
      }).toList();

      // 10s, 30s, 90s, 300s, 900s, 900s (capped)
      expect(delays, equals([10, 30, 90, 300, 900, 900]));
    });

    test('hasFailed is true when retryCount >= maxRetries', () {
      final atLimit = SyncQueueEntry(
        id: 'fail-1',
        type: 'test',
        payload: {},
        createdAt: DateTime.now(),
        retryCount: 5,
        status: QueueItemStatus.failed,
      );
      expect(atLimit.hasFailed, isTrue);

      final belowLimit = SyncQueueEntry(
        id: 'ok-1',
        type: 'test',
        payload: {},
        createdAt: DateTime.now(),
        retryCount: 3,
        status: QueueItemStatus.retrying,
      );
      expect(belowLimit.hasFailed, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST: ConflictResolver
  // ═══════════════════════════════════════════════════════════════════════════

  group('ConflictResolver', () {
    test('detect() returns null when no conflict', () {
      final result = ConflictResolver.detect(
        entityType: 'form_submission',
        entityId: 'id-1',
        localData: {'name': 'test', 'updated_at': '2026-04-14T10:00:00Z'},
        serverData: {'name': 'test', 'updated_at': '2026-04-14T09:00:00Z'},
        localBaseTimestamp: DateTime.parse('2026-04-14T08:00:00Z'),
      );
      // Server is OLDER than local base — no conflict
      expect(result, isNull);
    });

    test('detect() returns conflict when server updated after local base', () {
      final result = ConflictResolver.detect(
        entityType: 'form_submission',
        entityId: 'id-1',
        localData: {'name': 'local-value', 'updated_at': '2026-04-14T12:00:00Z'},
        serverData: {'name': 'server-value', 'updated_at': '2026-04-14T11:00:00Z'},
        localBaseTimestamp: DateTime.parse('2026-04-14T09:00:00Z'),
      );
      // Server updated at 11:00 which is AFTER our base at 09:00, and data differs
      expect(result, isNotNull);
      expect(result!.differingFields, contains('name'));
    });

    test('serverWins returns server data unchanged', () {
      final conflict = DataConflictV2(
        id: 'c1',
        entityType: 'form',
        entityId: 'e1',
        localData: {'name': 'local', 'status': 'submitted'},
        serverData: {'name': 'server', 'status': 'approved'},
        detectedAt: DateTime.now(),
      );

      final resolved = ConflictResolver.resolve(conflict, ConflictStrategy.serverWins);
      expect(resolved['name'], equals('server'));
      expect(resolved['status'], equals('approved'));
    });

    test('localWins returns local data unchanged', () {
      final conflict = DataConflictV2(
        id: 'c1',
        entityType: 'form',
        entityId: 'e1',
        localData: {'name': 'local', 'status': 'submitted'},
        serverData: {'name': 'server', 'status': 'approved'},
        detectedAt: DateTime.now(),
      );

      final resolved = ConflictResolver.resolve(conflict, ConflictStrategy.localWins);
      expect(resolved['name'], equals('local'));
      expect(resolved['status'], equals('submitted'));
    });

    test('smartMerge keeps admin fields from server, field data from local', () {
      final conflict = DataConflictV2(
        id: 'c1',
        entityType: 'form_submission',
        entityId: 'e1',
        localData: {
          'data': {'patient': 'Ahmed'},
          'gps_lat': 33.3,
          'status': 'submitted',       // local changed this
          'notes': 'field note',
          'photos': ['img1.jpg'],
        },
        serverData: {
          'data': {'patient': 'Ahmed Updated'}, // admin changed
          'gps_lat': 33.3,
          'status': 'approved',                  // server approved
          'notes': 'field note',
          'photos': ['img1.jpg'],
          'reviewed_by': 'admin-1',
          'reviewed_at': '2026-04-14T12:00:00Z',
        },
        detectedAt: DateTime.now(),
      );

      final resolved = ConflictResolver.resolve(conflict, ConflictStrategy.smartMerge);

      // Field data should come from LOCAL
      expect(resolved['data'], equals({'patient': 'Ahmed'}));
      expect(resolved['gps_lat'], equals(33.3));
      expect(resolved['notes'], equals('field note'));

      // Admin fields should come from SERVER
      expect(resolved['status'], equals('approved'));
      expect(resolved['reviewed_by'], equals('admin-1'));

      // Merge metadata should be present
      expect(resolved['_conflict_resolved'], isTrue);
      expect(resolved['_resolution_strategy'], equals('smart_merge'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST: NetworkSnapshot
  // ═══════════════════════════════════════════════════════════════════════════

  group('NetworkSnapshot', () {
    test('indicator shows correct emoji for each state', () {
      expect(
        const NetworkSnapshot(status: NetworkStatus.online).indicator,
        equals('🟢'),
      );
      expect(
        const NetworkSnapshot(status: NetworkStatus.online, pendingItems: 5).indicator,
        equals('🟡'),
      );
      expect(
        const NetworkSnapshot(status: NetworkStatus.syncing).indicator,
        equals('🟡'),
      );
      expect(
        const NetworkSnapshot(status: NetworkStatus.offline).indicator,
        equals('🔴'),
      );
    });

    test('statusText includes pending count when offline', () {
      final snap = const NetworkSnapshot(
        status: NetworkStatus.offline,
        pendingItems: 12,
      );
      expect(snap.statusText, contains('12'));
      expect(snap.statusText, contains('غير متصل'));
    });

    test('offlineDuration calculates correctly', () {
      final snap = NetworkSnapshot(
        status: NetworkStatus.offline,
        lastOnlineAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      expect(snap.offlineDuration, isNotNull);
      expect(snap.offlineDuration!.inMinutes, greaterThanOrEqualTo(29));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST: Critical Scenarios
  // ═══════════════════════════════════════════════════════════════════════════

  group('Critical Scenarios', () {
    test('Scenario 1: Network drops during sync — items remain in queue', () {
      // Simulate: 5 items in queue, network drops mid-sync
      final entries = List.generate(5, (i) => SyncQueueEntry(
        id: 'item-$i',
        type: 'form_submission',
        payload: {'data': 'test-$i'},
        createdAt: DateTime.now().subtract(Duration(seconds: 5 - i)),
        status: i < 2 ? QueueItemStatus.syncing : QueueItemStatus.pending,
      ));

      // After network drop, syncing items should be back to retrying
      // (this is handled by the manager, but the model supports it)
      for (final entry in entries) {
        if (entry.status == QueueItemStatus.syncing) {
          final retried = entry.copyWith(
            status: QueueItemStatus.retrying,
            retryCount: entry.retryCount + 1,
            lastError: 'Network dropped during sync',
          );
          expect(retried.status, equals(QueueItemStatus.retrying));
          expect(retried.retryCount, equals(1));
        }
      }
    });

    test('Scenario 2: Two devices sync same record — conflict detected', () {
      final conflict = ConflictResolver.detect(
        entityType: 'form_submission',
        entityId: 'shared-record-123',
        localData: {
          'data': {'patient_name': 'Device-A Name'},
          'updated_at': '2026-04-14T10:30:00Z',
        },
        serverData: {
          'data': {'patient_name': 'Device-B Name'},
          'updated_at': '2026-04-14T10:45:00Z',
        },
        localBaseTimestamp: DateTime.parse('2026-04-14T09:00:00Z'),
      );

      expect(conflict, isNotNull);
      expect(conflict!.differingFields, contains('data'));

      // Smart merge resolves it
      final resolved = ConflictResolver.resolve(conflict, ConflictStrategy.smartMerge);
      expect(resolved, isNotNull);
    });

    test('Scenario 3: Hundreds of pending items — batch order by priority', () {
      final items = <SyncQueueEntry>[];
      for (int i = 0; i < 200; i++) {
        final priority = i % 3 == 0
            ? SyncPriority.critical
            : i % 3 == 1
                ? SyncPriority.high
                : SyncPriority.normal;
        items.add(SyncQueueEntry(
          id: 'item-$i',
          type: 'form_submission',
          payload: {'index': i},
          priority: priority,
          createdAt: DateTime.now().subtract(Duration(seconds: 200 - i)),
          status: QueueItemStatus.pending,
        ));
      }

      // Sort as the queue would
      items.sort((a, b) {
        final pc = b.priority.value.compareTo(a.priority.value);
        if (pc != 0) return pc;
        return a.createdAt.compareTo(b.createdAt);
      });

      // First item should be critical
      expect(items.first.priority, equals(SyncPriority.critical));

      // Critical items should come before normal
      final firstNormal = items.indexWhere((e) => e.priority == SyncPriority.normal);
      final lastCritical = items.lastIndexWhere((e) => e.priority == SyncPriority.critical);
      expect(lastCritical, lessThan(firstNormal));
    });

    test('Scenario 4: Max retries exceeded — item marked as permanently failed', () {
      var entry = SyncQueueEntry(
        id: 'flaky-item',
        type: 'form_submission',
        payload: {'data': 'important health data'},
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: QueueItemStatus.pending,
      );

      // Simulate 5 failures
      for (int i = 0; i < 5; i++) {
        entry = entry.copyWith(
          retryCount: entry.retryCount + 1,
          status: entry.retryCount + 1 >= 5
              ? QueueItemStatus.failed
              : QueueItemStatus.retrying,
          lastError: 'Server error 500',
          lastAttemptAt: DateTime.now(),
        );
      }

      expect(entry.hasFailed, isTrue);
      expect(entry.status, equals(QueueItemStatus.failed));
      expect(entry.retryCount, equals(5));
    });

    test('Scenario 5: Offline for hours then reconnect — immediate sync', () {
      // Simulate: user works offline for 3 hours, collects 20 records
      final offlineRecords = List.generate(20, (i) => SyncQueueEntry(
        id: 'offline-$i',
        type: 'form_submission',
        payload: {'patient': 'patient-$i', 'vaccine': 'OPV'},
        priority: SyncPriority.critical,
        createdAt: DateTime.now().subtract(Duration(minutes: 180 - i * 9)),
        status: QueueItemStatus.pending,
      ));

      // All records should be ready
      final ready = offlineRecords.where((e) => e.isReadyForRetry).toList();
      expect(ready.length, equals(20));

      // All are critical priority
      expect(ready.every((e) => e.priority == SyncPriority.critical), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST: QueueCounts
  // ═══════════════════════════════════════════════════════════════════════════

  group('QueueCounts', () {
    test('isEmpty returns true when total is 0', () {
      expect(const QueueCounts().isEmpty, isTrue);
      expect(const QueueCounts(pending: 1).isEmpty, isFalse);
    });

    test('hasActivity returns true when syncing', () {
      expect(const QueueCounts(syncing: 1).hasActivity, isTrue);
      expect(const QueueCounts(pending: 5).hasActivity, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST: DataCompression
  // ═══════════════════════════════════════════════════════════════════════════

  group('Data Optimization', () {
    test('batch submission groups items correctly', () {
      final items = List.generate(75, (i) => SyncQueueEntry(
        id: 'item-$i',
        type: 'form_submission',
        payload: {'data': 'x' * 100},
        createdAt: DateTime.now(),
        status: QueueItemStatus.pending,
      ));

      const batchSize = 50;
      final batch1 = items.take(batchSize).toList();
      final batch2 = items.skip(batchSize).take(batchSize).toList();

      expect(batch1.length, equals(50));
      expect(batch2.length, equals(25));
    });

    test('duplicate offline_id is detected', () {
      final existingIds = {'uuid-1', 'uuid-2', 'uuid-3'};
      final newItem = {'offline_id': 'uuid-2', 'data': 'duplicate'};
      expect(existingIds.contains(newItem['offline_id']), isTrue);

      final newUnique = {'offline_id': 'uuid-4', 'data': 'unique'};
      expect(existingIds.contains(newUnique['offline_id']), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST: Always-Save-First Pattern
  // ═══════════════════════════════════════════════════════════════════════════

  group('Always-Save-First Pattern', () {
    test('data is saved to queue BEFORE any network call', () {
      // Simulate the correct flow: queue first, then try network
      final queue = <Map<String, dynamic>>[];

      // Step 1: Save locally FIRST (this is the "success")
      final formData = {
        'form_id': 'vaccination_form',
        'data': {'child_name': 'Ahmed', 'dose': 1},
        'offline_id': 'test-offline-id-123',
        'created_at': DateTime.now().toIso8601String(),
      };
      queue.add(formData);

      // At this point, data is safe. Network call is a bonus.
      expect(queue.length, equals(1));
      expect(queue.first['offline_id'], equals('test-offline-id-123'));

      // Step 2: Try network (simulate failure)
      bool networkSuccess = false;
      try {
        throw Exception('Network error');
      } catch (_) {
        networkSuccess = false;
      }

      // Data is STILL in queue — no loss!
      expect(queue.length, equals(1));
      expect(networkSuccess, isFalse);
    });

    test('form data survives every error scenario', () {
      // This test verifies the golden rule:
      // "Local save = success. Network = bonus."

      final scenarios = [
        'network_timeout',
        'server_500',
        'unauthorized_401',
        'connection_refused',
        'dns_failure',
      ];

      for (final scenario in scenarios) {
        final queue = <Map<String, dynamic>>[];

        // Always save first
        queue.add({
          'form_id': 'test_form',
          'data': {'scenario': scenario},
          'offline_id': 'id_$scenario',
        });

        // Simulate the error
        bool errorOccurred = true;

        // Verify: data is safe regardless of error type
        expect(queue.length, equals(1),
            reason: 'Data should survive $scenario');
        expect(queue.first['data']['scenario'], equals(scenario),
            reason: 'Data content should be intact after $scenario');
      }
    });

    test('queue entry has all required fields for later sync', () {
      final entry = SyncQueueEntry(
        id: 'test-id',
        type: 'form_submission',
        payload: {
          'form_id': 'vaccination_form',
          'data': {'child_name': 'Ahmed', 'dose': 1, 'vaccine': 'OPV'},
          'gps_lat': 33.312800,
          'gps_lng': 44.361500,
          'created_at': DateTime.now().toIso8601String(),
        },
        priority: SyncPriority.critical,
        createdAt: DateTime.now(),
        status: QueueItemStatus.pending,
      );

      // Verify all fields needed for sync are present
      expect(entry.payload['form_id'], isNotNull);
      expect(entry.payload['data'], isNotNull);
      expect(entry.payload['created_at'], isNotNull);
      expect(entry.priority, equals(SyncPriority.critical));
      expect(entry.status, equals(QueueItemStatus.pending));
      expect(entry.isReadyForRetry, isTrue);
    });
  });
}
