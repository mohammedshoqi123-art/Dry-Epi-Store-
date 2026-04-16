import 'package:flutter_test/flutter_test.dart';
import 'package:epi_core/epi_core.dart';

void main() {
  group('AppConfig', () {
    test('app name is set correctly', () {
      expect(AppConfig.appName, equals("EPI Supervisor's"));
      expect(AppConfig.appNameAr, equals("EPI Supervisor's"));
    });

    test('app version is set correctly', () {
      expect(AppConfig.appVersion, equals('2.1.0'));
      expect(AppConfig.buildNumber, equals(1));
    });

    test('sync interval is reasonable', () {
      expect(AppConfig.syncInterval.inMinutes, equals(5));
      expect(AppConfig.maxRetries, greaterThanOrEqualTo(3));
    });

    test('GPS settings are reasonable', () {
      expect(AppConfig.gpsAccuracyMeters, greaterThan(0));
      expect(AppConfig.gpsTimeout.inSeconds, greaterThan(0));
    });

    test('security settings are reasonable', () {
      expect(AppConfig.maxLoginAttempts, greaterThanOrEqualTo(3));
      expect(AppConfig.sessionTimeoutMinutes, greaterThan(0));
    });

    test('pagination settings are reasonable', () {
      expect(AppConfig.defaultPageSize, greaterThan(0));
      expect(AppConfig.maxPageSize,
          greaterThanOrEqualTo(AppConfig.defaultPageSize));
    });

    test('photo settings are reasonable', () {
      expect(AppConfig.maxPhotoSizeMb, greaterThan(0));
      expect(AppConfig.maxPhotosPerSubmission, equals(1));
    });

    test('environment defaults to production', () {
      expect(AppConfig.isProduction, isTrue);
      expect(AppConfig.isDevelopment, isFalse);
    });
  });
}
