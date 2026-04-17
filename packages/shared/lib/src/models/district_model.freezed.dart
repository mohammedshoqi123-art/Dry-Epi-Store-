// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'district_model';

mixin $_$DistrictModel {

  String get id;
  String get governorateId;
  String get nameAr;
  String get nameEn;
  String get code;
  double? get centerLat;
  double? get centerLng;
  int? get population;
  bool get isActive;
  DateTime? get createdAt;
  DateTime? get updatedAt;
  Map<String, get dynamic;

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DistrictModel copyWith({
    String? id,
    String? governorateId,
    String? nameAr,
    String? nameEn,
    String? code,
    double?? centerLat,
    double?? centerLng,
    int?? population,
    bool? isActive,
    DateTime?? createdAt,
    DateTime?? updatedAt,
    Map<String,? dynamic,
  }) => $DistrictModel(
    id: id ?? this.id,
    governorateId: governorateId ?? this.governorateId,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    code: code ?? this.code,
    centerLat: centerLat ?? this.centerLat,
    centerLng: centerLng ?? this.centerLng,
    population: population ?? this.population,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    dynamic: dynamic ?? this.dynamic,
  );
}

/// @nodoc
class $DistrictModel extends DistrictModel {
  const $DistrictModel({
    required super.id,
    required super.governorateId,
    required super.nameAr,
    required super.nameEn,
    required super.code,
    super.centerLat,
    super.centerLng,
    super.population,
    super.isActive,
    super.createdAt,
    super.updatedAt,
    super.dynamic,
  });

  factory $DistrictModel.fromJson(Map<String, dynamic> json) => _$DistrictModelFromJson(json);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is $DistrictModel &&
            const DeepCollectionEquality().equals(other.id, id) &&
            const DeepCollectionEquality().equals(other.governorateId, governorateId) &&
            const DeepCollectionEquality().equals(other.nameAr, nameAr) &&
            const DeepCollectionEquality().equals(other.nameEn, nameEn) &&
            const DeepCollectionEquality().equals(other.code, code) &&
            const DeepCollectionEquality().equals(other.centerLat, centerLat) &&
            const DeepCollectionEquality().equals(other.centerLng, centerLng) &&
            const DeepCollectionEquality().equals(other.population, population) &&
            const DeepCollectionEquality().equals(other.isActive, isActive) &&
            const DeepCollectionEquality().equals(other.createdAt, createdAt) &&
            const DeepCollectionEquality().equals(other.updatedAt, updatedAt) &&
            const DeepCollectionEquality().equals(other.dynamic, dynamic));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(id),
    const DeepCollectionEquality().hash(governorateId),
    const DeepCollectionEquality().hash(nameAr),
    const DeepCollectionEquality().hash(nameEn),
    const DeepCollectionEquality().hash(code),
    const DeepCollectionEquality().hash(centerLat),
    const DeepCollectionEquality().hash(centerLng),
    const DeepCollectionEquality().hash(population),
    const DeepCollectionEquality().hash(isActive),
    const DeepCollectionEquality().hash(createdAt),
    const DeepCollectionEquality().hash(updatedAt),
    const DeepCollectionEquality().hash(dynamic),
  );

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  @override
  $DistrictModel copyWith({
    Object? id = freezed,
    Object? governorateId = freezed,
    Object? nameAr = freezed,
    Object? nameEn = freezed,
    Object? code = freezed,
    Object? centerLat = freezed,
    Object? centerLng = freezed,
    Object? population = freezed,
    Object? isActive = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? dynamic = freezed,
  }) => $DistrictModel(
    id: id == freezed ? this.id : id as String,
    governorateId: governorateId == freezed ? this.governorateId : governorateId as String,
    nameAr: nameAr == freezed ? this.nameAr : nameAr as String,
    nameEn: nameEn == freezed ? this.nameEn : nameEn as String,
    code: code == freezed ? this.code : code as String,
    centerLat: centerLat == freezed ? this.centerLat : centerLat as double?,
    centerLng: centerLng == freezed ? this.centerLng : centerLng as double?,
    population: population == freezed ? this.population : population as int?,
    isActive: isActive == freezed ? this.isActive : isActive as bool,
    createdAt: createdAt == freezed ? this.createdAt : createdAt as DateTime?,
    updatedAt: updatedAt == freezed ? this.updatedAt : updatedAt as DateTime?,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
  );

  @override
  String toString() {
    return 'DistrictModel(id: $id, governorateId: $governorateId, nameAr: $nameAr, nameEn: $nameEn, code: $code, centerLat: $centerLat, centerLng: $centerLng, population: $population, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, dynamic: $dynamic)';
  }
}
