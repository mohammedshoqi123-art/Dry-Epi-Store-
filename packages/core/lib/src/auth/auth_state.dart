/// Authentication state for the EPI Supervisor platform.
/// Manual implementation (no Freezed) to avoid code-generation dependency.
library;

enum UserRole {
  admin,
  central,
  governorate,
  district,
  dataEntry;

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
      case UserRole.dataEntry:
        return 1;
    }
  }

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
      case UserRole.dataEntry:
        return 'مدخل بيانات';
    }
  }

  bool canManage(UserRole other) => hierarchyLevel > other.hierarchyLevel;

  bool get canViewAllGovernorates => hierarchyLevel >= 4;
  bool get canViewAllDistricts => hierarchyLevel >= 3;
  bool get canApprove => hierarchyLevel >= 3;
  bool get canManageUsers => hierarchyLevel >= 4;
  bool get canManageForms => hierarchyLevel >= 4;
  bool get canExport => hierarchyLevel >= 3;
  bool get canUseAI => hierarchyLevel >= 3;
  bool get canViewAuditLogs => hierarchyLevel >= 4;
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
    return UserRole.values.cast<UserRole?>().firstWhere(
          (r) => r?.name == role || (role == 'data_entry' && r == UserRole.dataEntry),
          orElse: () => null,
        );
  }

  @override
  String toString() => 'AuthState(auth=$isAuthenticated, role=$role, user=$fullName)';
}

// Extension for StreamProvider compatibility
extension AuthStateStreamX on AuthState {
  bool get isAdmin => role == UserRole.admin;
  bool get isCentral => role == UserRole.central;
  bool get isGovernorate => role == UserRole.governorate;
  bool get isDistrict => role == UserRole.district;
  bool get isDataEntry => role == UserRole.dataEntry;
}
