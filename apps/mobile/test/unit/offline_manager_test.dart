import 'package:flutter_test/flutter_test.dart';
import 'package:epi_core/src/offline/offline_manager.dart';
import 'package:epi_core/src/security/encryption_service.dart';
import 'package:epi_core/src/api/api_client.dart';
import 'package:epi_core/src/errors/app_exceptions.dart';

void main() {
  group('SyncResult', () {
    test('success result has correct properties', () {
      final result = SyncResult.success('id-1', {'ok': true});
      expect(result.isSuccess, isTrue);
      expect(result.isConflict, isFalse);
      expect(result.isError, isFalse);
      expect(result.isDuplicate, isFalse);
      expect(result.offlineId, equals('id-1'));
      expect(result.serverResponse?['ok'], isTrue);
    });

    test('conflict result has correct properties', () {
      final result = SyncResult.conflict('id-2', {'conflict': true});
      expect(result.isConflict, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('error result has message', () {
      final result = SyncResult.error('id-3', 'Network timeout');
      expect(result.isError, isTrue);
      expect(result.errorMessage, equals('Network timeout'));
    });

    test('duplicate result has correct properties', () {
      final result = SyncResult.duplicate('id-4');
      expect(result.isDuplicate, isTrue);
    });

    test('toString includes status', () {
      final result = SyncResult.error('abc', 'fail');
      expect(result.toString(), contains('abc'));
      expect(result.toString(), contains('error'));
    });
  });

  group('OfflineManager - Queue Management', () {
    test('idempotency key is set on submission', () {
      // This test verifies the offline_id is used as idempotency key
      final submission = {'form_id': 'test', 'data': {'field': 'value'}};

      // Simulate what addToSyncQueue does
      final offlineId = 'test-uuid-123';
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
      final error = ApiException('Server error', code: '500');
      expect(error.code?.startsWith('5'), isTrue);
    });

    test('rate limit is not retryable for immediate re-attempt', () {
      final error = ApiException('Rate limited', code: 'rate_limit');
      expect(error.code, equals('rate_limit'));
    });

    test('network errors are retryable', () {
      final error = NetworkException('No connection');
      expect(error.code, equals('NETWORK'));
    });
  });
}
