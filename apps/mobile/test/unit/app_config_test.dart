import 'package:flutter_test/flutter_test.dart';
import 'package:epi_core/src/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('app metadata is set', () {
      expect(AppConfig.appName, equals('EPI Supervisor'));
      expect(AppConfig.appNameAr, equals('منصة مشرف EPI'));
      expect(AppConfig.appVersion, equals('1.0.0'));
    });

    test('pagination limits are sensible', () {
      expect(AppConfig.defaultPageSize, greaterThan(0));
      expect(AppConfig.maxPageSize, greaterThanOrEqualTo(AppConfig.defaultPageSize));
    });

    test('sync config is sensible', () {
      expect(AppConfig.syncInterval.inMinutes, greaterThan(0));
      expect(AppConfig.maxRetries, greaterThan(0));
      expect(AppConfig.maxQueueSize, greaterThan(0));
    });

    test('GPS config is sensible', () {
      expect(AppConfig.gpsAccuracyMeters, greaterThan(0));
      expect(AppConfig.gpsTimeout.inSeconds, greaterThan(0));
    });

    test('security config is sensible', () {
      expect(AppConfig.sessionTimeoutMinutes, greaterThan(0));
      expect(AppConfig.maxLoginAttempts, greaterThan(0));
      expect(AppConfig.lockoutDuration.inMinutes, greaterThan(0));
    });

    test('environment flags are consistent', () {
      // Can't be both production and development
      expect(AppConfig.isProduction && AppConfig.isDevelopment, isFalse);
    });
  });
}
