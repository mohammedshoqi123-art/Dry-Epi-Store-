import 'package:flutter_test/flutter_test.dart';
import 'package:epi_core/src/auth/auth_state.dart';

void main() {
  group('UserRole', () {
    test('hierarchy levels are correct', () {
      expect(UserRole.admin.hierarchyLevel, equals(5));
      expect(UserRole.central.hierarchyLevel, equals(4));
      expect(UserRole.governorate.hierarchyLevel, equals(3));
      expect(UserRole.district.hierarchyLevel, equals(2));
      expect(UserRole.teamLead.hierarchyLevel, equals(1));
    });

    test('admin can manage all roles', () {
      expect(UserRole.admin.canManage(UserRole.central), isTrue);
      expect(UserRole.admin.canManage(UserRole.governorate), isTrue);
      expect(UserRole.admin.canManage(UserRole.district), isTrue);
      expect(UserRole.admin.canManage(UserRole.teamLead), isTrue);
    });

    test('data_entry cannot manage anyone', () {
      expect(UserRole.teamLead.canManage(UserRole.admin), isFalse);
      expect(UserRole.teamLead.canManage(UserRole.central), isFalse);
      expect(UserRole.teamLead.canManage(UserRole.district), isFalse);
    });

    test('no role can manage itself', () {
      for (final role in UserRole.values) {
        expect(role.canManage(role), isFalse);
      }
    });

    test('Arabic names are set', () {
      expect(UserRole.admin.nameAr, equals('مدير النظام'));
      expect(UserRole.central.nameAr, equals('مركزي'));
      expect(UserRole.governorate.nameAr, equals('محافظة'));
      expect(UserRole.district.nameAr, equals('منطقة'));
      expect(UserRole.teamLead.nameAr, equals('مشرف فريق'));
    });

    test('permission flags are correct', () {
      // Admin has all permissions
      expect(UserRole.admin.canViewAllGovernorates, isTrue);
      expect(UserRole.admin.canApprove, isTrue);
      expect(UserRole.admin.canManageUsers, isTrue);
      expect(UserRole.admin.canViewAuditLogs, isTrue);
      expect(UserRole.admin.canUseAI, isTrue);

      // Data entry has minimal permissions
      expect(UserRole.teamLead.canViewAllGovernorates, isFalse);
      expect(UserRole.teamLead.canApprove, isFalse);
      expect(UserRole.teamLead.canManageUsers, isFalse);
      expect(UserRole.teamLead.canViewAuditLogs, isFalse);
      expect(UserRole.teamLead.canUseAI, isFalse);

      // Governorate can approve
      expect(UserRole.governorate.canApprove, isTrue);
      expect(UserRole.governorate.canExport, isTrue);
    });
  });

  group('AuthState', () {
    test('default state is unauthenticated', () {
      const state = AuthState();
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.role, isNull);
    });

    test('copyWith preserves unset fields', () {
      const original = AuthState(userId: '123', email: 'test@test.com');
      final updated = original.copyWith(isAuthenticated: true);
      expect(updated.isAuthenticated, isTrue);
      expect(updated.userId, equals('123'));
      expect(updated.email, equals('test@test.com'));
    });

    test('copyWith overrides set fields', () {
      const original = AuthState(fullName: 'Old Name');
      final updated = original.copyWith(fullName: 'New Name');
      expect(updated.fullName, equals('New Name'));
    });

    test('toJson and fromJson roundtrip', () {
      const original = AuthState(
        isAuthenticated: true,
        userId: 'user-123',
        email: 'admin@epi.local',
        role: UserRole.admin,
        fullName: 'مدير النظام',
      );

      final json = original.toJson();
      final restored = AuthState.fromJson(json);

      expect(restored.isAuthenticated, isTrue);
      expect(restored.userId, equals('user-123'));
      expect(restored.email, equals('admin@epi.local'));
      expect(restored.role, equals(UserRole.admin));
      expect(restored.fullName, equals('مدير النظام'));
    });

    test('fromJson handles data_entry role name', () {
      final restored = AuthState.fromJson({'role': 'data_entry'});
      expect(restored.role, equals(UserRole.teamLead));
    });

    test('fromJson handles null role', () {
      final restored = AuthState.fromJson({});
      expect(restored.role, isNull);
    });
  });
}
