// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'form_model';

mixin $_$FormModel {

  String get id;
  String get titleAr;
  String get titleEn;
  String? get descriptionAr;
  String? get descriptionEn;
  Map<String, get dynamic;
  int get version;
  bool get isActive;
  bool get requiresGps;
  bool get requiresPhoto;
  int get maxPhotos;
  List<String> get allowedRoles;
  String? get createdBy;
  DateTime? get createdAt;
  DateTime? get updatedAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FormModel copyWith({
    String? id,
    String? titleAr,
    String? titleEn,
    String?? descriptionAr,
    String?? descriptionEn,
    Map<String,? dynamic,
    int? version,
    bool? isActive,
    bool? requiresGps,
    bool? requiresPhoto,
    int? maxPhotos,
    List<String>? allowedRoles,
    String?? createdBy,
    DateTime?? createdAt,
    DateTime?? updatedAt,
  }) => $FormModel(
    id: id ?? this.id,
    titleAr: titleAr ?? this.titleAr,
    titleEn: titleEn ?? this.titleEn,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEn: descriptionEn ?? this.descriptionEn,
    dynamic: dynamic ?? this.dynamic,
    version: version ?? this.version,
    isActive: isActive ?? this.isActive,
    requiresGps: requiresGps ?? this.requiresGps,
    requiresPhoto: requiresPhoto ?? this.requiresPhoto,
    maxPhotos: maxPhotos ?? this.maxPhotos,
    allowedRoles: allowedRoles ?? this.allowedRoles,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// @nodoc
class $FormModel extends FormModel {
  const $FormModel({
    required super.id,
    required super.titleAr,
    required super.titleEn,
    super.descriptionAr,
    super.descriptionEn,
    required super.dynamic,
    super.version,
    super.isActive,
    super.requiresGps,
    super.requiresPhoto,
    super.maxPhotos,
    super.allowedRoles,
    super.createdBy,
    super.createdAt,
    super.updatedAt,
  });

  factory $FormModel.fromJson(Map<String, dynamic> json) => _$FormModelFromJson(json);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is $FormModel &&
            const DeepCollectionEquality().equals(other.id, id) &&
            const DeepCollectionEquality().equals(other.titleAr, titleAr) &&
            const DeepCollectionEquality().equals(other.titleEn, titleEn) &&
            const DeepCollectionEquality().equals(other.descriptionAr, descriptionAr) &&
            const DeepCollectionEquality().equals(other.descriptionEn, descriptionEn) &&
            const DeepCollectionEquality().equals(other.dynamic, dynamic) &&
            const DeepCollectionEquality().equals(other.version, version) &&
            const DeepCollectionEquality().equals(other.isActive, isActive) &&
            const DeepCollectionEquality().equals(other.requiresGps, requiresGps) &&
            const DeepCollectionEquality().equals(other.requiresPhoto, requiresPhoto) &&
            const DeepCollectionEquality().equals(other.maxPhotos, maxPhotos) &&
            const DeepCollectionEquality().equals(other.allowedRoles, allowedRoles) &&
            const DeepCollectionEquality().equals(other.createdBy, createdBy) &&
            const DeepCollectionEquality().equals(other.createdAt, createdAt) &&
            const DeepCollectionEquality().equals(other.updatedAt, updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(id),
    const DeepCollectionEquality().hash(titleAr),
    const DeepCollectionEquality().hash(titleEn),
    const DeepCollectionEquality().hash(descriptionAr),
    const DeepCollectionEquality().hash(descriptionEn),
    const DeepCollectionEquality().hash(dynamic),
    const DeepCollectionEquality().hash(version),
    const DeepCollectionEquality().hash(isActive),
    const DeepCollectionEquality().hash(requiresGps),
    const DeepCollectionEquality().hash(requiresPhoto),
    const DeepCollectionEquality().hash(maxPhotos),
    const DeepCollectionEquality().hash(allowedRoles),
    const DeepCollectionEquality().hash(createdBy),
    const DeepCollectionEquality().hash(createdAt),
    const DeepCollectionEquality().hash(updatedAt),
  );

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  @override
  $FormModel copyWith({
    Object? id = freezed,
    Object? titleAr = freezed,
    Object? titleEn = freezed,
    Object? descriptionAr = freezed,
    Object? descriptionEn = freezed,
    Object? dynamic = freezed,
    Object? version = freezed,
    Object? isActive = freezed,
    Object? requiresGps = freezed,
    Object? requiresPhoto = freezed,
    Object? maxPhotos = freezed,
    Object? allowedRoles = freezed,
    Object? createdBy = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) => $FormModel(
    id: id == freezed ? this.id : id as String,
    titleAr: titleAr == freezed ? this.titleAr : titleAr as String,
    titleEn: titleEn == freezed ? this.titleEn : titleEn as String,
    descriptionAr: descriptionAr == freezed ? this.descriptionAr : descriptionAr as String?,
    descriptionEn: descriptionEn == freezed ? this.descriptionEn : descriptionEn as String?,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
    version: version == freezed ? this.version : version as int,
    isActive: isActive == freezed ? this.isActive : isActive as bool,
    requiresGps: requiresGps == freezed ? this.requiresGps : requiresGps as bool,
    requiresPhoto: requiresPhoto == freezed ? this.requiresPhoto : requiresPhoto as bool,
    maxPhotos: maxPhotos == freezed ? this.maxPhotos : maxPhotos as int,
    allowedRoles: allowedRoles == freezed ? this.allowedRoles : allowedRoles as List<String>,
    createdBy: createdBy == freezed ? this.createdBy : createdBy as String?,
    createdAt: createdAt == freezed ? this.createdAt : createdAt as DateTime?,
    updatedAt: updatedAt == freezed ? this.updatedAt : updatedAt as DateTime?,
  );

  @override
  String toString() {
    return 'FormModel(id: $id, titleAr: $titleAr, titleEn: $titleEn, descriptionAr: $descriptionAr, descriptionEn: $descriptionEn, dynamic: $dynamic, version: $version, isActive: $isActive, requiresGps: $requiresGps, requiresPhoto: $requiresPhoto, maxPhotos: $maxPhotos, allowedRoles: $allowedRoles, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

mixin $_$FormField {

  String get key;
  String get labelAr;
  String? get labelEn;
  bool get required;
  String? get hint;
  dynamic get defaultValue;
  List<dynamic>? get options;
  dynamic get min;
  dynamic get max;
  String? get pattern;
  Map<String, get dynamic;

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FormField copyWith({
    String? key,
    String? labelAr,
    String?? labelEn,
    bool? required,
    String?? hint,
    dynamic? defaultValue,
    List<dynamic>?? options,
    dynamic? min,
    dynamic? max,
    String?? pattern,
    Map<String,? dynamic,
  }) => $FormField(
    key: key ?? this.key,
    labelAr: labelAr ?? this.labelAr,
    labelEn: labelEn ?? this.labelEn,
    required: required ?? this.required,
    hint: hint ?? this.hint,
    defaultValue: defaultValue ?? this.defaultValue,
    options: options ?? this.options,
    min: min ?? this.min,
    max: max ?? this.max,
    pattern: pattern ?? this.pattern,
    dynamic: dynamic ?? this.dynamic,
  );
}

/// @nodoc
class $FormField extends FormField {
  const $FormField({
    required super.key,
    required super.labelAr,
    super.labelEn,
    required super.required,
    super.hint,
    super.defaultValue,
    super.options,
    super.min,
    super.max,
    super.pattern,
    super.dynamic,
  });

  factory $FormField.fromJson(Map<String, dynamic> json) => _$FormFieldFromJson(json);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is $FormField &&
            const DeepCollectionEquality().equals(other.key, key) &&
            const DeepCollectionEquality().equals(other.labelAr, labelAr) &&
            const DeepCollectionEquality().equals(other.labelEn, labelEn) &&
            const DeepCollectionEquality().equals(other.required, required) &&
            const DeepCollectionEquality().equals(other.hint, hint) &&
            const DeepCollectionEquality().equals(other.defaultValue, defaultValue) &&
            const DeepCollectionEquality().equals(other.options, options) &&
            const DeepCollectionEquality().equals(other.min, min) &&
            const DeepCollectionEquality().equals(other.max, max) &&
            const DeepCollectionEquality().equals(other.pattern, pattern) &&
            const DeepCollectionEquality().equals(other.dynamic, dynamic));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(key),
    const DeepCollectionEquality().hash(labelAr),
    const DeepCollectionEquality().hash(labelEn),
    const DeepCollectionEquality().hash(required),
    const DeepCollectionEquality().hash(hint),
    const DeepCollectionEquality().hash(defaultValue),
    const DeepCollectionEquality().hash(options),
    const DeepCollectionEquality().hash(min),
    const DeepCollectionEquality().hash(max),
    const DeepCollectionEquality().hash(pattern),
    const DeepCollectionEquality().hash(dynamic),
  );

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  @override
  $FormField copyWith({
    Object? key = freezed,
    Object? labelAr = freezed,
    Object? labelEn = freezed,
    Object? required = freezed,
    Object? hint = freezed,
    Object? defaultValue = freezed,
    Object? options = freezed,
    Object? min = freezed,
    Object? max = freezed,
    Object? pattern = freezed,
    Object? dynamic = freezed,
  }) => $FormField(
    key: key == freezed ? this.key : key as String,
    labelAr: labelAr == freezed ? this.labelAr : labelAr as String,
    labelEn: labelEn == freezed ? this.labelEn : labelEn as String?,
    required: required == freezed ? this.required : required as bool,
    hint: hint == freezed ? this.hint : hint as String?,
    defaultValue: defaultValue == freezed ? this.defaultValue : defaultValue as dynamic,
    options: options == freezed ? this.options : options as List<dynamic>?,
    min: min == freezed ? this.min : min as dynamic,
    max: max == freezed ? this.max : max as dynamic,
    pattern: pattern == freezed ? this.pattern : pattern as String?,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
  );

  @override
  String toString() {
    return 'FormField(key: $key, labelAr: $labelAr, labelEn: $labelEn, required: $required, hint: $hint, defaultValue: $defaultValue, options: $options, min: $min, max: $max, pattern: $pattern, dynamic: $dynamic)';
  }
}
