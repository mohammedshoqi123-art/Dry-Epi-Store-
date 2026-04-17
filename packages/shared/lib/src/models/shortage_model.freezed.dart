// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shortage_model';

mixin $_$ShortageModel {

  String get id;
  String? get submissionId;
  String get reportedBy;
  String? get governorateId;
  String? get districtId;
  String get itemName;
  String? get itemCategory;
  int? get quantityNeeded;
  int get quantityAvailable;
  String get unit;
  String get severity;
  String? get notes;
  bool get isResolved;
  DateTime? get resolvedAt;
  String? get resolvedBy;
  DateTime? get createdAt;
  DateTime? get updatedAt;
  Map<String, get dynamic;
  Map<String, get dynamic;
  Map<String, get dynamic;

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ShortageModel copyWith({
    String? id,
    String?? submissionId,
    String? reportedBy,
    String?? governorateId,
    String?? districtId,
    String? itemName,
    String?? itemCategory,
    int?? quantityNeeded,
    int? quantityAvailable,
    String? unit,
    String? severity,
    String?? notes,
    bool? isResolved,
    DateTime?? resolvedAt,
    String?? resolvedBy,
    DateTime?? createdAt,
    DateTime?? updatedAt,
    Map<String,? dynamic,
    Map<String,? dynamic,
    Map<String,? dynamic,
  }) => $ShortageModel(
    id: id ?? this.id,
    submissionId: submissionId ?? this.submissionId,
    reportedBy: reportedBy ?? this.reportedBy,
    governorateId: governorateId ?? this.governorateId,
    districtId: districtId ?? this.districtId,
    itemName: itemName ?? this.itemName,
    itemCategory: itemCategory ?? this.itemCategory,
    quantityNeeded: quantityNeeded ?? this.quantityNeeded,
    quantityAvailable: quantityAvailable ?? this.quantityAvailable,
    unit: unit ?? this.unit,
    severity: severity ?? this.severity,
    notes: notes ?? this.notes,
    isResolved: isResolved ?? this.isResolved,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    resolvedBy: resolvedBy ?? this.resolvedBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    dynamic: dynamic ?? this.dynamic,
    dynamic: dynamic ?? this.dynamic,
    dynamic: dynamic ?? this.dynamic,
  );
}

/// @nodoc
class $ShortageModel extends ShortageModel {
  const $ShortageModel({
    required super.id,
    super.submissionId,
    required super.reportedBy,
    super.governorateId,
    super.districtId,
    required super.itemName,
    super.itemCategory,
    super.quantityNeeded,
    super.quantityAvailable,
    super.unit,
    super.severity,
    super.notes,
    super.isResolved,
    super.resolvedAt,
    super.resolvedBy,
    super.createdAt,
    super.updatedAt,
    super.dynamic,
    super.dynamic,
    super.dynamic,
  });

  factory $ShortageModel.fromJson(Map<String, dynamic> json) => _$ShortageModelFromJson(json);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is $ShortageModel &&
            const DeepCollectionEquality().equals(other.id, id) &&
            const DeepCollectionEquality().equals(other.submissionId, submissionId) &&
            const DeepCollectionEquality().equals(other.reportedBy, reportedBy) &&
            const DeepCollectionEquality().equals(other.governorateId, governorateId) &&
            const DeepCollectionEquality().equals(other.districtId, districtId) &&
            const DeepCollectionEquality().equals(other.itemName, itemName) &&
            const DeepCollectionEquality().equals(other.itemCategory, itemCategory) &&
            const DeepCollectionEquality().equals(other.quantityNeeded, quantityNeeded) &&
            const DeepCollectionEquality().equals(other.quantityAvailable, quantityAvailable) &&
            const DeepCollectionEquality().equals(other.unit, unit) &&
            const DeepCollectionEquality().equals(other.severity, severity) &&
            const DeepCollectionEquality().equals(other.notes, notes) &&
            const DeepCollectionEquality().equals(other.isResolved, isResolved) &&
            const DeepCollectionEquality().equals(other.resolvedAt, resolvedAt) &&
            const DeepCollectionEquality().equals(other.resolvedBy, resolvedBy) &&
            const DeepCollectionEquality().equals(other.createdAt, createdAt) &&
            const DeepCollectionEquality().equals(other.updatedAt, updatedAt) &&
            const DeepCollectionEquality().equals(other.dynamic, dynamic) &&
            const DeepCollectionEquality().equals(other.dynamic, dynamic) &&
            const DeepCollectionEquality().equals(other.dynamic, dynamic));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(id),
    const DeepCollectionEquality().hash(submissionId),
    const DeepCollectionEquality().hash(reportedBy),
    const DeepCollectionEquality().hash(governorateId),
    const DeepCollectionEquality().hash(districtId),
    const DeepCollectionEquality().hash(itemName),
    const DeepCollectionEquality().hash(itemCategory),
    const DeepCollectionEquality().hash(quantityNeeded),
    const DeepCollectionEquality().hash(quantityAvailable),
    const DeepCollectionEquality().hash(unit),
    const DeepCollectionEquality().hash(severity),
    const DeepCollectionEquality().hash(notes),
    const DeepCollectionEquality().hash(isResolved),
    const DeepCollectionEquality().hash(resolvedAt),
    const DeepCollectionEquality().hash(resolvedBy),
    const DeepCollectionEquality().hash(createdAt),
    const DeepCollectionEquality().hash(updatedAt),
    const DeepCollectionEquality().hash(dynamic),
    const DeepCollectionEquality().hash(dynamic),
    const DeepCollectionEquality().hash(dynamic),
  );

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  @override
  $ShortageModel copyWith({
    Object? id = freezed,
    Object? submissionId = freezed,
    Object? reportedBy = freezed,
    Object? governorateId = freezed,
    Object? districtId = freezed,
    Object? itemName = freezed,
    Object? itemCategory = freezed,
    Object? quantityNeeded = freezed,
    Object? quantityAvailable = freezed,
    Object? unit = freezed,
    Object? severity = freezed,
    Object? notes = freezed,
    Object? isResolved = freezed,
    Object? resolvedAt = freezed,
    Object? resolvedBy = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? dynamic = freezed,
    Object? dynamic = freezed,
    Object? dynamic = freezed,
  }) => $ShortageModel(
    id: id == freezed ? this.id : id as String,
    submissionId: submissionId == freezed ? this.submissionId : submissionId as String?,
    reportedBy: reportedBy == freezed ? this.reportedBy : reportedBy as String,
    governorateId: governorateId == freezed ? this.governorateId : governorateId as String?,
    districtId: districtId == freezed ? this.districtId : districtId as String?,
    itemName: itemName == freezed ? this.itemName : itemName as String,
    itemCategory: itemCategory == freezed ? this.itemCategory : itemCategory as String?,
    quantityNeeded: quantityNeeded == freezed ? this.quantityNeeded : quantityNeeded as int?,
    quantityAvailable: quantityAvailable == freezed ? this.quantityAvailable : quantityAvailable as int,
    unit: unit == freezed ? this.unit : unit as String,
    severity: severity == freezed ? this.severity : severity as String,
    notes: notes == freezed ? this.notes : notes as String?,
    isResolved: isResolved == freezed ? this.isResolved : isResolved as bool,
    resolvedAt: resolvedAt == freezed ? this.resolvedAt : resolvedAt as DateTime?,
    resolvedBy: resolvedBy == freezed ? this.resolvedBy : resolvedBy as String?,
    createdAt: createdAt == freezed ? this.createdAt : createdAt as DateTime?,
    updatedAt: updatedAt == freezed ? this.updatedAt : updatedAt as DateTime?,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
  );

  @override
  String toString() {
    return 'ShortageModel(id: $id, submissionId: $submissionId, reportedBy: $reportedBy, governorateId: $governorateId, districtId: $districtId, itemName: $itemName, itemCategory: $itemCategory, quantityNeeded: $quantityNeeded, quantityAvailable: $quantityAvailable, unit: $unit, severity: $severity, notes: $notes, isResolved: $isResolved, resolvedAt: $resolvedAt, resolvedBy: $resolvedBy, createdAt: $createdAt, updatedAt: $updatedAt, dynamic: $dynamic, dynamic: $dynamic, dynamic: $dynamic)';
  }
}
