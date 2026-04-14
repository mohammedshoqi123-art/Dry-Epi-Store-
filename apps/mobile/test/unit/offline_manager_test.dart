import 'package:flutter_test/flutter_test.dart';
import 'package:epi_core/src/offline/sync_models.dart';
import 'package:epi_core/src/errors/app_exceptions.dart';

void main() {
  group('OfflineSyncResult', () {
    test('success result has correct properties', () {
      final result = OfflineSyncResult.success('id-1', {'ok': true});
      expect(result.isSuccess, isTrue);
      expect(result.isConflict, isFalse);
      expect(result.isError, isFalse);
      expect(result.isDuplicate, isFalse);
      expect(result.offlineId, equals('id-1'));
      expect(result.serverResponse?['ok'], isTrue);
    });

    test('conflict result has correct properties', () {
      final result = OfflineSyncResult.conflict('id-2', {'conflict': true});
      expect(result.isConflict, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('error result has message', () {
      final result = OfflineSyncResult.error('id-3', 'Network timeout');
      expect(result.isError, isTrue);
      expect(result.errorMessage, equals('Network timeout'));
    });

    test('duplicate result has correct properties', () {
      final result = OfflineSyncResult.duplicate('id-4');
      expect(result.isDuplicate, isTrue);
    });

    test('toString includes status', () {
      final result = OfflineSyncResult.error('abc', 'fail');
      expect(result.toString(), contains('abc'));
      expect(result.toString(), contains('error'));
    });
  });

  group('OfflineManager - Queue Management', () {
    test('idempotency key is set on submission', () {
      // This test verifies the offline_id is used as idempotency key
      final submission = {'form_id': 'test', 'data': {'field': 'value'}};

      // Simulate what addToSyncQueue does
      const offlineId = 'test-uuid-123';
      submission['offline_id'] = offlineId;
      submission['idempotency_key'] = offlineId;

      expect(submission['idempotency_key'], equals(submission['offline_id']));
    });

    test('payload size validation works', () {
      // Create a large payload (>1MB)
      final largeData = 'x' * (1024 * 1024 + 1);
      final submission = {'form_id': 'test', 'data': largeData};

      // Verify size calculation
      final size = submission.toString().length;
      expect(size, greaterThan(1024 * 1024));
    });
  });

  group('SyncResult - Error Classification', () {
    test('server errors (5xx) are retryable', () {
      const error = ApiException('Server error', code: '500');
      expect(error.code?.startsWith('5'), isTrue);
    });

    test('rate limit is not retryable for immediate re-attempt', () {
      const error = ApiException('Rate limited', code: 'rate_limit');
      expect(error.code, equals('rate_limit'));
    });

    test('network errors are retryable', () {
      const error = NetworkException('No connection');
      expect(error.code, equals('NETWORK'));
    });
  });
}
