// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'submission_model';

mixin $_$SubmissionModel {

  String get id;
  String get formId;
  String get submittedBy;
  String? get governorateId;
  String? get districtId;
  String get status;
  Map<String, get dynamic;
  double? get gpsLat;
  double? get gpsLng;
  double? get gpsAccuracy;
  List<String> get photos;
  String? get notes;
  String? get reviewedBy;
  DateTime? get reviewedAt;
  String? get reviewNotes;
  DateTime? get submittedAt;
  String? get deviceId;
  String? get appVersion;
  bool get isOffline;
  String? get offlineId;
  DateTime? get syncedAt;
  DateTime? get createdAt;
  DateTime? get updatedAt;
  Map<String, get dynamic;
  Map<String, get dynamic;

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SubmissionModel copyWith({
    String? id,
    String? formId,
    String? submittedBy,
    String?? governorateId,
    String?? districtId,
    String? status,
    Map<String,? dynamic,
    double?? gpsLat,
    double?? gpsLng,
    double?? gpsAccuracy,
    List<String>? photos,
    String?? notes,
    String?? reviewedBy,
    DateTime?? reviewedAt,
    String?? reviewNotes,
    DateTime?? submittedAt,
    String?? deviceId,
    String?? appVersion,
    bool? isOffline,
    String?? offlineId,
    DateTime?? syncedAt,
    DateTime?? createdAt,
    DateTime?? updatedAt,
    Map<String,? dynamic,
    Map<String,? dynamic,
  }) => $SubmissionModel(
    id: id ?? this.id,
    formId: formId ?? this.formId,
    submittedBy: submittedBy ?? this.submittedBy,
    governorateId: governorateId ?? this.governorateId,
    districtId: districtId ?? this.districtId,
    status: status ?? this.status,
    dynamic: dynamic ?? this.dynamic,
    gpsLat: gpsLat ?? this.gpsLat,
    gpsLng: gpsLng ?? this.gpsLng,
    gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
    photos: photos ?? this.photos,
    notes: notes ?? this.notes,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    reviewNotes: reviewNotes ?? this.reviewNotes,
    submittedAt: submittedAt ?? this.submittedAt,
    deviceId: deviceId ?? this.deviceId,
    appVersion: appVersion ?? this.appVersion,
    isOffline: isOffline ?? this.isOffline,
    offlineId: offlineId ?? this.offlineId,
    syncedAt: syncedAt ?? this.syncedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    dynamic: dynamic ?? this.dynamic,
    dynamic: dynamic ?? this.dynamic,
  );
}

/// @nodoc
class $SubmissionModel extends SubmissionModel {
  const $SubmissionModel({
    required super.id,
    required super.formId,
    required super.submittedBy,
    super.governorateId,
    super.districtId,
    super.status,
    super.dynamic,
    super.gpsLat,
    super.gpsLng,
    super.gpsAccuracy,
    super.photos,
    super.notes,
    super.reviewedBy,
    super.reviewedAt,
    super.reviewNotes,
    super.submittedAt,
    super.deviceId,
    super.appVersion,
    super.isOffline,
    super.offlineId,
    super.syncedAt,
    super.createdAt,
    super.updatedAt,
    super.dynamic,
    super.dynamic,
  });

  factory $SubmissionModel.fromJson(Map<String, dynamic> json) => _$SubmissionModelFromJson(json);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is $SubmissionModel &&
            const DeepCollectionEquality().equals(other.id, id) &&
            const DeepCollectionEquality().equals(other.formId, formId) &&
            const DeepCollectionEquality().equals(other.submittedBy, submittedBy) &&
            const DeepCollectionEquality().equals(other.governorateId, governorateId) &&
            const DeepCollectionEquality().equals(other.districtId, districtId) &&
            const DeepCollectionEquality().equals(other.status, status) &&
            const DeepCollectionEquality().equals(other.dynamic, dynamic) &&
            const DeepCollectionEquality().equals(other.gpsLat, gpsLat) &&
            const DeepCollectionEquality().equals(other.gpsLng, gpsLng) &&
            const DeepCollectionEquality().equals(other.gpsAccuracy, gpsAccuracy) &&
            const DeepCollectionEquality().equals(other.photos, photos) &&
            const DeepCollectionEquality().equals(other.notes, notes) &&
            const DeepCollectionEquality().equals(other.reviewedBy, reviewedBy) &&
            const DeepCollectionEquality().equals(other.reviewedAt, reviewedAt) &&
            const DeepCollectionEquality().equals(other.reviewNotes, reviewNotes) &&
            const DeepCollectionEquality().equals(other.submittedAt, submittedAt) &&
            const DeepCollectionEquality().equals(other.deviceId, deviceId) &&
            const DeepCollectionEquality().equals(other.appVersion, appVersion) &&
            const DeepCollectionEquality().equals(other.isOffline, isOffline) &&
            const DeepCollectionEquality().equals(other.offlineId, offlineId) &&
            const DeepCollectionEquality().equals(other.syncedAt, syncedAt) &&
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
    const DeepCollectionEquality().hash(formId),
    const DeepCollectionEquality().hash(submittedBy),
    const DeepCollectionEquality().hash(governorateId),
    const DeepCollectionEquality().hash(districtId),
    const DeepCollectionEquality().hash(status),
    const DeepCollectionEquality().hash(dynamic),
    const DeepCollectionEquality().hash(gpsLat),
    const DeepCollectionEquality().hash(gpsLng),
    const DeepCollectionEquality().hash(gpsAccuracy),
    const DeepCollectionEquality().hash(photos),
    const DeepCollectionEquality().hash(notes),
    const DeepCollectionEquality().hash(reviewedBy),
    const DeepCollectionEquality().hash(reviewedAt),
    const DeepCollectionEquality().hash(reviewNotes),
    const DeepCollectionEquality().hash(submittedAt),
    const DeepCollectionEquality().hash(deviceId),
    const DeepCollectionEquality().hash(appVersion),
    const DeepCollectionEquality().hash(isOffline),
    const DeepCollectionEquality().hash(offlineId),
    const DeepCollectionEquality().hash(syncedAt),
    const DeepCollectionEquality().hash(createdAt),
    const DeepCollectionEquality().hash(updatedAt),
    const DeepCollectionEquality().hash(dynamic),
    const DeepCollectionEquality().hash(dynamic),
  );

  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  @override
  $SubmissionModel copyWith({
    Object? id = freezed,
    Object? formId = freezed,
    Object? submittedBy = freezed,
    Object? governorateId = freezed,
    Object? districtId = freezed,
    Object? status = freezed,
    Object? dynamic = freezed,
    Object? gpsLat = freezed,
    Object? gpsLng = freezed,
    Object? gpsAccuracy = freezed,
    Object? photos = freezed,
    Object? notes = freezed,
    Object? reviewedBy = freezed,
    Object? reviewedAt = freezed,
    Object? reviewNotes = freezed,
    Object? submittedAt = freezed,
    Object? deviceId = freezed,
    Object? appVersion = freezed,
    Object? isOffline = freezed,
    Object? offlineId = freezed,
    Object? syncedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? dynamic = freezed,
    Object? dynamic = freezed,
  }) => $SubmissionModel(
    id: id == freezed ? this.id : id as String,
    formId: formId == freezed ? this.formId : formId as String,
    submittedBy: submittedBy == freezed ? this.submittedBy : submittedBy as String,
    governorateId: governorateId == freezed ? this.governorateId : governorateId as String?,
    districtId: districtId == freezed ? this.districtId : districtId as String?,
    status: status == freezed ? this.status : status as String,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
    gpsLat: gpsLat == freezed ? this.gpsLat : gpsLat as double?,
    gpsLng: gpsLng == freezed ? this.gpsLng : gpsLng as double?,
    gpsAccuracy: gpsAccuracy == freezed ? this.gpsAccuracy : gpsAccuracy as double?,
    photos: photos == freezed ? this.photos : photos as List<String>,
    notes: notes == freezed ? this.notes : notes as String?,
    reviewedBy: reviewedBy == freezed ? this.reviewedBy : reviewedBy as String?,
    reviewedAt: reviewedAt == freezed ? this.reviewedAt : reviewedAt as DateTime?,
    reviewNotes: reviewNotes == freezed ? this.reviewNotes : reviewNotes as String?,
    submittedAt: submittedAt == freezed ? this.submittedAt : submittedAt as DateTime?,
    deviceId: deviceId == freezed ? this.deviceId : deviceId as String?,
    appVersion: appVersion == freezed ? this.appVersion : appVersion as String?,
    isOffline: isOffline == freezed ? this.isOffline : isOffline as bool,
    offlineId: offlineId == freezed ? this.offlineId : offlineId as String?,
    syncedAt: syncedAt == freezed ? this.syncedAt : syncedAt as DateTime?,
    createdAt: createdAt == freezed ? this.createdAt : createdAt as DateTime?,
    updatedAt: updatedAt == freezed ? this.updatedAt : updatedAt as DateTime?,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
    dynamic: dynamic == freezed ? this.dynamic : dynamic as Map<String,,
  );

  @override
  String toString() {
    return 'SubmissionModel(id: $id, formId: $formId, submittedBy: $submittedBy, governorateId: $governorateId, districtId: $districtId, status: $status, dynamic: $dynamic, gpsLat: $gpsLat, gpsLng: $gpsLng, gpsAccuracy: $gpsAccuracy, photos: $photos, notes: $notes, reviewedBy: $reviewedBy, reviewedAt: $reviewedAt, reviewNotes: $reviewNotes, submittedAt: $submittedAt, deviceId: $deviceId, appVersion: $appVersion, isOffline: $isOffline, offlineId: $offlineId, syncedAt: $syncedAt, createdAt: $createdAt, updatedAt: $updatedAt, dynamic: $dynamic, dynamic: $dynamic)';
  }
}
