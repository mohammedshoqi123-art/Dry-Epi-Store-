import 'package:flutter_test/flutter_test.dart';
import 'package:epi_core/epi_core.dart';

void main() {
  group('AppConfig', () {
    test('app name is set correctly', () {
      expect(AppConfig.appName, 'EPI Supervisor');
      expect(AppConfig.appNameAr, 'منصة مشرف EPI');
    });

    test('app version is set correctly', () {
      expect(AppConfig.appVersion, '1.0.0');
      expect(AppConfig.buildNumber, 1);
    });

    test('pagination defaults are valid', () {
      expect(AppConfig.defaultPageSize, greaterThan(0));
      expect(AppConfig.maxPageSize, greaterThanOrEqualTo(AppConfig.defaultPageSize));
    });

    test('sync configuration is valid', () {
      expect(AppConfig.syncInterval.inMinutes, greaterThan(0));
      expect(AppConfig.maxRetries, greaterThan(0));
      expect(AppConfig.maxQueueSize, greaterThan(0));
    });

    test('GPS configuration is valid', () {
      expect(AppConfig.gpsAccuracyMeters, greaterThan(0));
      expect(AppConfig.gpsTimeout.inSeconds, greaterThan(0));
    });

    test('security configuration is valid', () {
      expect(AppConfig.sessionTimeoutMinutes, greaterThan(0));
      expect(AppConfig.maxLoginAttempts, greaterThan(0));
    });
  });

  group('UserRole', () {
    test('hierarchy levels are correct', () {
      expect(UserRole.admin.hierarchyLevel, 5);
      expect(UserRole.central.hierarchyLevel, 4);
      expect(UserRole.governorate.hierarchyLevel, 3);
      expect(UserRole.district.hierarchyLevel, 2);
      expect(UserRole.dataEntry.hierarchyLevel, 1);
    });

    test('admin can manage all roles', () {
      expect(UserRole.admin.canManage(UserRole.central), isTrue);
      expect(UserRole.admin.canManage(UserRole.governorate), isTrue);
      expect(UserRole.admin.canManage(UserRole.district), isTrue);
      expect(UserRole.admin.canManage(UserRole.dataEntry), isTrue);
    });

    test('data entry cannot manage anyone', () {
      expect(UserRole.dataEntry.canManage(UserRole.admin), isFalse);
      expect(UserRole.dataEntry.canManage(UserRole.central), isFalse);
    });

    test('Arabic names are correct', () {
      expect(UserRole.admin.nameAr, 'مدير النظام');
      expect(UserRole.central.nameAr, 'مركزي');
      expect(UserRole.governorate.nameAr, 'محافظة');
      expect(UserRole.district.nameAr, 'منطقة');
      expect(UserRole.dataEntry.nameAr, 'مدخل بيانات');
    });

    test('permissions are correct', () {
      expect(UserRole.admin.canViewAllGovernorates, isTrue);
      expect(UserRole.central.canViewAllGovernorates, isTrue);
      expect(UserRole.governorate.canViewAllGovernorates, isFalse);

      expect(UserRole.admin.canManageUsers, isTrue);
      expect(UserRole.central.canManageUsers, isTrue);
      expect(UserRole.governorate.canManageUsers, isFalse);

      expect(UserRole.admin.canUseAI, isTrue);
      expect(UserRole.governorate.canUseAI, isTrue);
      expect(UserRole.district.canUseAI, isFalse);
    });
  });

  group('AuthState', () {
    test('default state is unauthenticated', () {
      const state = AuthState();
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.userId, isNull);
      expect(state.role, isNull);
    });

    test('copyWith works correctly', () {
      const state = AuthState();
      final updated = state.copyWith(
        isAuthenticated: true,
        userId: 'test-id',
        role: UserRole.admin,
      );
      expect(updated.isAuthenticated, isTrue);
      expect(updated.userId, 'test-id');
      expect(updated.role, UserRole.admin);
    });

    test('toJson and fromJson work correctly', () {
      const state = AuthState(
        isAuthenticated: true,
        userId: 'test-id',
        email: 'test@example.com',
        role: UserRole.admin,
        fullName: 'Test User',
      );

      final json = state.toJson();
      expect(json['is_authenticated'], isTrue);
      expect(json['user_id'], 'test-id');
      expect(json['email'], 'test@example.com');
      expect(json['role'], 'admin');

      final restored = AuthState.fromJson(json);
      expect(restored.isAuthenticated, isTrue);
      expect(restored.userId, 'test-id');
      expect(restored.role, UserRole.admin);
    });
  });

  group('AppExceptions', () {
    test('ApiException has correct properties', () {
      const exception = ApiException('Test error', code: '500');
      expect(exception.message, 'Test error');
      expect(exception.code, '500');
    });

    test('PermissionException has correct code', () {
      const exception = PermissionException('No access');
      expect(exception.code, 'PERMISSION_DENIED');
    });

    test('ValidationException supports field errors', () {
      const exception = ValidationException(
        'Validation failed',
        fieldErrors: {'email': 'Invalid email'},
      );
      expect(exception.fieldErrors?['email'], 'Invalid email');
    });
  });

  group('EncryptionService', () {
    late EncryptionService encryption;

    setUp(() {
      encryption = EncryptionService();
    });

    test('encrypt and decrypt are reversible', () {
      const plaintext = 'Hello, EPI Supervisor!';
      final encrypted = encryption.encrypt(plaintext);
      final decrypted = encryption.decrypt(encrypted);
      expect(decrypted, plaintext);
    });

    test('encrypted text is different from plaintext', () {
      const plaintext = 'Sensitive data';
      final encrypted = encryption.encrypt(plaintext);
      expect(encrypted, isNot(plaintext));
    });

    test('hash produces consistent results', () {
      const input = 'test-data';
      final hash1 = encryption.hash(input);
      final hash2 = encryption.hash(input);
      expect(hash1, hash2);
    });

    test('verifyIntegrity works correctly', () {
      const data = 'important-data';
      final hash = encryption.hash(data);
      expect(encryption.verifyIntegrity(data, hash), isTrue);
      expect(encryption.verifyIntegrity('tampered-data', hash), isFalse);
    });
  });

  group('GeoUtils', () {
    test('isValidCoordinate validates correctly', () {
      expect(GeoUtils.isValidCoordinate(33.3152, 44.3661), isTrue);
      expect(GeoUtils.isValidCoordinate(-91, 0), isFalse);
      expect(GeoUtils.isValidCoordinate(0, 181), isFalse);
      expect(GeoUtils.isValidCoordinate(null, null), isFalse);
    });

    test('isWithinIraq validates correctly', () {
      expect(GeoUtils.isWithinIraq(33.3152, 44.3661), isTrue);  // Baghdad
      expect(GeoUtils.isWithinIraq(51.5074, -0.1278), isFalse); // London
    });

    test('distance calculation is reasonable', () {
      // Baghdad to Basra ~450km
      final distance = GeoUtils.distanceKm(33.3152, 44.3661, 30.5085, 47.7804);
      expect(distance, greaterThan(400));
      expect(distance, lessThan(500));
    });

    test('formatDistance formats correctly', () {
      expect(GeoUtils.formatDistance(500), contains('م'));
      expect(GeoUtils.formatDistance(1500), contains('كم'));
    });
  });

  group('RBACService', () {
    test('canPerformAction works correctly', () {
      expect(RBACService.canPerformAction(UserRole.admin, RBACAction.manageUsers), isTrue);
      expect(RBACService.canPerformAction(UserRole.dataEntry, RBACAction.manageUsers), isFalse);
      expect(RBACService.canPerformAction(UserRole.dataEntry, RBACAction.submitForms), isTrue);
    });

    test('assignableRoles works correctly', () {
      final adminRoles = RBACService.assignableRoles(UserRole.admin);
      expect(adminRoles.length, UserRole.values.length);

      final dataEntryRoles = RBACService.assignableRoles(UserRole.dataEntry);
      expect(dataEntryRoles, isEmpty);
    });

    test('enforcePermission throws for insufficient access', () {
      expect(
        () => RBACService.enforcePermission(UserRole.dataEntry, RBACAction.manageUsers),
        throwsA(isA<PermissionException>()),
      );
    });
  });

  group('SyncQueueItem', () {
    test('toJson and fromJson work correctly', () {
      final item = SyncQueueItem(
        id: 'test-id',
        type: 'form_submission',
        payload: {'form_id': 'abc'},
        metadata: {},
        createdAt: DateTime(2024, 1, 1),
        retryCount: 0,
        status: SyncStatus.pending,
      );

      final json = item.toJson();
      expect(json['id'], 'test-id');
      expect(json['type'], 'form_submission');
      expect(json['status'], 'pending');

      final restored = SyncQueueItem.fromJson(json);
      expect(restored.id, 'test-id');
      expect(restored.status, SyncStatus.pending);
    });

    test('copyWith works correctly', () {
      final item = SyncQueueItem(
        id: 'test-id',
        type: 'form_submission',
        payload: {},
        metadata: {},
        createdAt: DateTime(2024, 1, 1),
        retryCount: 0,
        status: SyncStatus.pending,
      );

      final updated = item.copyWith(status: SyncStatus.failed, retryCount: 3);
      expect(updated.status, SyncStatus.failed);
      expect(updated.retryCount, 3);
      expect(updated.id, 'test-id'); // unchanged
    });
  });
}
