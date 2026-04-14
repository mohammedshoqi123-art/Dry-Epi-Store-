/// Authentication state for the EPI Supervisor platform.
library;

enum UserRole {
  admin,      // مدير النظام — full access
  central,    // مشرف مركزي — sees all governorate submissions, edit own only
  governorate,// مشرف محافظة — sees own governorate submissions, edit own only
  district,   // مشرف مديرية — sees own district submissions, edit own only
  data_entry; // مدخل بيانات — sees own submissions only, can edit them

  int get hierarchyLevel {
    switch (this) {
      case UserRole.admin:
        return 5;
      case UserRole.central:
        return 4;
      case UserRole.governorate:
        return 3;
      case UserRole.district:
        return 2;
      case UserRole.data_entry:
        return 1;
    }
  }

  /// Database-compatible role name (matches SQL ENUM: user_role)
  String get dbValue => name;

  String get nameAr {
    switch (this) {
      case UserRole.admin:
        return 'مدير النظام';
      case UserRole.central:
        return 'مركزي';
      case UserRole.governorate:
        return 'محافظة';
      case UserRole.district:
        return 'منطقة';
      case UserRole.data_entry:
        return 'مدخل بيانات';
    }
  }

  /// Hide admin dashboard + user management for non-admins
  bool get canAccessAdminDashboard => this == UserRole.admin;
  bool get canManageUsers => hierarchyLevel >= 4; // admin + central
  bool get canManageForms => hierarchyLevel >= 4;
  bool get canViewAuditLogs => hierarchyLevel >= 4;

  /// Viewing scope — what data they can see
  bool get canViewAllGovernorates => hierarchyLevel >= 4;
  bool get canViewAllDistricts => hierarchyLevel >= 3;

  /// Edit permissions — can only edit their own submissions
  bool get canApprove => hierarchyLevel >= 3;
  bool get canExport => true; // all roles
  bool get canUseAI => true; // all roles

  bool canManage(UserRole other) => hierarchyLevel > other.hierarchyLevel;
}

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? email;
  final UserRole? role;
  final String? governorateId;
  final String? districtId;
  final String? fullName;
  final String? avatarUrl;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.userId,
    this.email,
    this.role,
    this.governorateId,
    this.districtId,
    this.fullName,
    this.avatarUrl,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? email,
    UserRole? role,
    String? governorateId,
    String? districtId,
    String? fullName,
    String? avatarUrl,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      governorateId: governorateId ?? this.governorateId,
      districtId: districtId ?? this.districtId,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_authenticated': isAuthenticated,
        'user_id': userId,
        'email': email,
        'role': role?.name,
        'governorate_id': governorateId,
        'district_id': districtId,
        'full_name': fullName,
        'avatar_url': avatarUrl,
      };

  factory AuthState.fromJson(Map<String, dynamic> json) => AuthState(
        isAuthenticated: json['is_authenticated'] as bool? ?? false,
        userId: json['user_id'] as String?,
        email: json['email'] as String?,
        role: _parseRole(json['role'] as String?),
        governorateId: json['governorate_id'] as String?,
        districtId: json['district_id'] as String?,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  static UserRole? _parseRole(String? role) {
    if (role == null) return null;
    // Direct mapping — enum names now match SQL ENUM values
    const roleMap = {
      'admin': UserRole.admin,
      'central': UserRole.central,
      'governorate': UserRole.governorate,
      'district': UserRole.district,
      'data_entry': UserRole.data_entry,
      'teamLead': UserRole.data_entry, // backward compat
    };
    return roleMap[role];
  }

  @override
  String toString() => 'AuthState(auth=$isAuthenticated, role=$role, user=$fullName)';
}

extension AuthStateStreamX on AuthState {
  bool get isAdmin => role == UserRole.admin;
  bool get isCentral => role == UserRole.central;
  bool get isGovernorate => role == UserRole.governorate;
  bool get isDistrict => role == UserRole.district;
  bool get isDataEntry => role == UserRole.data_entry;
}
