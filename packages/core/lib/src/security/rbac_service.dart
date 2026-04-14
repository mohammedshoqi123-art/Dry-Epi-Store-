import '../auth/auth_state.dart';
import '../errors/app_exceptions.dart';

class RBACService {
  // Role hierarchy: admin(5) > central(4) > governorate(3) > district(2) > data_entry(1)

  static bool canAccessResource(UserRole? role, {
    required String resourceOwnerId,
    required String currentUserId,
    String? resourceGovernorateId,
    String? resourceDistrictId,
    String? userGovernorateId,
    String? userDistrictId,
  }) {
    if (role == null) return false;

    // Admin can access everything
    if (role == UserRole.admin) return true;

    // Users can always access their own resources
    if (resourceOwnerId == currentUserId) return true;

    // Central can see everything
    if (role == UserRole.central) return true;

    // Governorate can see their governorate's resources
    if (role == UserRole.governorate) {
      return resourceGovernorateId == userGovernorateId;
    }

    // District can see their district's resources
    if (role == UserRole.district) {
      return resourceDistrictId == userDistrictId;
    }

    // Data entry can only see their own (already checked above)
    return false;
  }

  static bool canPerformAction(UserRole? role, RBACAction action) {
    if (role == null) return false;

    switch (action) {
      case RBACAction.viewAllData:
        return role.hierarchyLevel >= 4; // central+
      case RBACAction.manageUsers:
        return role.hierarchyLevel >= 4; // central+
      case RBACAction.manageForms:
        return role.hierarchyLevel >= 4; // central+
      case RBACAction.approveSubmissions:
        return role.hierarchyLevel >= 3; // governorate+
      case RBACAction.rejectSubmissions:
        return role.hierarchyLevel >= 3; // governorate+
      case RBACAction.exportData:
        return true; // all authenticated users
      case RBACAction.viewAnalytics:
        return true; // all authenticated users
      case RBACAction.submitForms:
        return true; // all authenticated users
      case RBACAction.viewOwnData:
        return true; // all authenticated users
      case RBACAction.viewMap:
        return true; // all authenticated users
      case RBACAction.manageGovernorates:
        return role == UserRole.admin;
      case RBACAction.manageDistricts:
        return role == UserRole.admin;
      case RBACAction.viewAuditLogs:
        return role.hierarchyLevel >= 4; // central+
      case RBACAction.useAI:
        return true; // all authenticated users
    }
  }

  static List<UserRole> assignableRoles(UserRole assignerRole) {
    switch (assignerRole) {
      case UserRole.admin:
        return UserRole.values;
      case UserRole.central:
        return [UserRole.governorate, UserRole.district, UserRole.data_entry];
      case UserRole.governorate:
        return [UserRole.district, UserRole.data_entry];
      case UserRole.district:
        return [UserRole.data_entry];
      case UserRole.data_entry:
        return [];
    }
  }

  static void enforcePermission(UserRole? role, RBACAction action) {
    if (!canPerformAction(role, action)) {
      throw PermissionException(
        'Insufficient permissions for action: ${action.name}',
      );
    }
  }
}

enum RBACAction {
  viewAllData,
  manageUsers,
  manageForms,
  approveSubmissions,
  rejectSubmissions,
  exportData,
  viewAnalytics,
  submitForms,
  viewOwnData,
  viewMap,
  manageGovernorates,
  manageDistricts,
  viewAuditLogs,
  useAI,
}
