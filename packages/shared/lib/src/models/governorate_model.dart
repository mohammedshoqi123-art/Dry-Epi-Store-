import 'package:freezed_annotation/freezed_annotation.dart';

part 'governorate_model.freezed.dart';
part 'governorate_model.g.dart';

@freezed
class GovernorateModel with _$GovernorateModel {
  const factory GovernorateModel({
    required String id,
    @JsonKey(name: 'name_ar') required String nameAr,
    @JsonKey(name: 'name_en') required String nameEn,
    required String code,
    @JsonKey(name: 'center_lat') double? centerLat,
    @JsonKey(name: 'center_lng') double? centerLng,
    int? population,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _GovernorateModel;

  factory GovernorateModel.fromJson(Map<String, dynamic> json) =>
      _$GovernorateModelFromJson(json);
}
