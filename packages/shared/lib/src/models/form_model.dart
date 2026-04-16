import 'package:freezed_annotation/freezed_annotation.dart';

part 'form_model.freezed.dart';
part 'form_model.g.dart';

@freezed
class FormModel with _$FormModel {
  const factory FormModel({
    required String id,
    @JsonKey(name: 'title_ar') required String titleAr,
    @JsonKey(name: 'title_en') required String titleEn,
    @JsonKey(name: 'description_ar') String? descriptionAr,
    @JsonKey(name: 'description_en') String? descriptionEn,
    required Map<String, dynamic> schema,
    @Default(1) int version,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'requires_gps') @Default(false) bool requiresGps,
    @JsonKey(name: 'requires_photo') @Default(false) bool requiresPhoto,
    @JsonKey(name: 'max_photos') @Default(5) int maxPhotos,
    @JsonKey(name: 'allowed_roles') @Default([]) List<String> allowedRoles,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _FormModel;

  factory FormModel.fromJson(Map<String, dynamic> json) =>
      _$FormModelFromJson(json);
}

@freezed
class FormField with _$FormField {
  const factory FormField({
    required String key,
    required String
        type, // text, number, select, multiselect, date, gps, photo, textarea
    @JsonKey(name: 'label_ar') required String labelAr,
    @JsonKey(name: 'label_en') String? labelEn,
    @Default(false) bool required,
    String? hint,
    dynamic defaultValue,
    List<dynamic>? options,
    dynamic min,
    dynamic max,
    String? pattern,
    Map<String, dynamic>? validation,
  }) = _FormField;

  factory FormField.fromJson(Map<String, dynamic> json) =>
      _$FormFieldFromJson(json);
}
