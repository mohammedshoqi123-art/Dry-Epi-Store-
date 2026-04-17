// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile_model';

mixin $_$UserProfileModel {

  String get id;
  String get email;
  String get fullName;
  String? get phone;
  String get role;
  String? get governorateId;
  String? get districtId;
  String? get avatarUrl;
  bool get isActive;
  DateTime? get lastLogin;
  DateTime? get createdAt;
  DateTime? get updatedAt;
  Map<String, get dynamic;
  Map<String, get dynamic;

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserProfileModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String?? phone,
    String? role,
    String?? governorateId,
    String?? districtId,
    String?? avatarUrl,
    bool? isActive,
    DateTime?? lastLogin,
    DateTime?? createdAt,
    DateTime?? updatedAt,
    Map<String,? dynamic,
    Map<String,? dynamic,
  }) => $UserProfileModel(
    id: id ?? this.id,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    governorateId: governorateId ?? this.governorateId,
    districtId: districtId ?? this.districtId,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isActive: isActive ?? this.isActive,
    lastLogin: lastLogin ?? this.lastLogin,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    dynamic: dynamic ?? this.dynamic,
    dynamic: dynamic ?? this.dynamic,
  );
}

/// @nodoc
class $UserProfileModel extends UserProfileModel {
  const $UserProfileModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.phone,
    super.role,
    super.governorateId,
    super.districtId,
    super.avatarUrl,
    super.isActive,
    super.lastLogin,
    super.createdAt,
    super.updatedAt,
    super.dynamic,
    super.dynamic,
  });

  factory $UserProfileModel.fromJson(Map<String, dynamic> json) => _$UserProfileModelFromJson(json);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is $UserProfileModel &&
            const DeepCollectionEquality().equals(other.id, id) &&
            const DeepCollectionEquality().equals(other.email, email) &&
            const DeepCollectionEquality().equals(other.fullName, fullName) &&
            const DeepCollectionEquality().equals(other.phone, phone) &&
            const DeepCollectionEquality().equals(other.role, role) &&
            const DeepCollectionEquality().equals(other.governorateId, governorateId) &&
            const DeepCollectionEquality().equals(other.districtId, districtId) &&
            const DeepCollectionEquality().equals(other.avatarUrl, avatarUrl) &&
            const DeepCollectionEquality().equals(other.isActive, isActive) &&
            const DeepCollectionEquality().equals(other.lastLogin, lastLogin) &&
            const DeepCollectionEquality().equals(other.createdAt, createdAt) &&
            const DeepCollectionEquality().equals(other.updatedAt, updatedAt) &&
            const DeepCollectionEquality().equals(other.dynamic, dynamic) &&
            const DeepCollectionEquality().equals(other.dynamic, dynamic));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(id),
    const DeepCollectionEquality().hash(email),
    const DeepCollectionEquality().hash(fullName),
    const DeepCollectionEquality().hash(phone),
    const DeepCollectionEquality().hash(role),
    const DeepCollectionEquality().hash(governorateId),
    const DeepCollectionEquality().hash(districtId),
    const DeepCollectionEquality().hash(avatarUrl),
    const DeepCollectionEquality().hash(isActive),
    const DeepCollectionEquality().hash(lastLogin),
    const DeepCollectionEquality().hash(createdAt),
    const DeepCollectionEquality().hash(updatedAt),
    const DeepCollectionEquality().hash(dynamic),
    const DeepCollectionEquality().hash(dynamic),
  );

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  @override
  $UserProfileModel copyWith({
    Object? id = freezed,
    Object? email = freezed,
    Object? fullName = freezed,
    Object? phone = freezed,
    Object? role = freezed,
    Object? governorateId = freezed,
    Object? districtId = freezed,
    Object? avatarUrl = freezed,
    Object? isActive = freezed,
    Object? lastLogin = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? dynamic = freezed,
    Object? dynamic = freezed,
  }) => $UserProfileModel(
    id: id == freezed ? this.id : id as String,
    email: email == freezed ? this.email : email as String,
    fullName: fullName == freezed ? this.fullName : fullName as String,
    phone: phone == freezed ? this.phone : phone as String?,
    role: role == freezed ? this.role : role as String,
    governorateId: governorateId == freezed ? this.governorateId : governorateId as String?,
    districtId: districtId == freezed ? this.districtId : districtId as String?,
    avatarUrl: avatarUrl == freezed ? this.avatarUrl : avatarUrl as String?,
    isActive: isActive == freezed ? this.isActive : isActive as bool,
    lastLogin: lastLogin == freezed ? this.lastLogin : lastLogin as DateTime?,
    createdAt: createdAt == freezed ? this.createdAt : createdAt as DateTime?,
    updatedAt: updatedAt == freezed ? this.updatedAt : updatedAt as DateTime?,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
  );

  @override
  String toString() {
    return 'UserProfileModel(id: $id, email: $email, fullName: $fullName, phone: $phone, role: $role, governorateId: $governorateId, districtId: $districtId, avatarUrl: $avatarUrl, isActive: $isActive, lastLogin: $lastLogin, createdAt: $createdAt, updatedAt: $updatedAt, dynamic: $dynamic, dynamic: $dynamic)';
  }
}
