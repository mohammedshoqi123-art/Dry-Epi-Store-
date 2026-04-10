import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile_model.freezed.dart';
part 'user_profile_model.g.dart';

@freezed
class UserProfileModel with _$UserProfileModel {
  const factory UserProfileModel({
    required String id,
    required String email,
    @JsonKey(name: 'full_name') required String fullName,
    String? phone,
    @Default('data_entry') String role,
    @JsonKey(name: 'governorate_id') String? governorateId,
    @JsonKey(name: 'district_id') String? districtId,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'last_login') DateTime? lastLogin,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    // Relations
    Map<String, dynamic>? governorates,
    Map<String, dynamic>? districts,
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) => _$UserProfileModelFromJson(json);
}
