// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'submission_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SubmissionModelImpl _$$SubmissionModelImplFromJson(
        Map<String, dynamic> json) =>
    _$SubmissionModelImpl(
      id: json['id'] as String,
      formId: json['form_id'] as String,
      submittedBy: json['submitted_by'] as String,
      governorateId: json['governorate_id'] as String?,
      districtId: json['district_id'] as String?,
      status: json['status'] as String? ?? 'draft',
      data: json['data'] as Map<String, dynamic>? ?? const {},
      gpsLat: (json['gps_lat'] as num?)?.toDouble(),
      gpsLng: (json['gps_lng'] as num?)?.toDouble(),
      gpsAccuracy: (json['gps_accuracy'] as num?)?.toDouble(),
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      notes: json['notes'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      reviewNotes: json['review_notes'] as String?,
      submittedAt: json['submitted_at'] == null
          ? null
          : DateTime.parse(json['submitted_at'] as String),
      deviceId: json['device_id'] as String?,
      appVersion: json['app_version'] as String?,
      isOffline: json['is_offline'] as bool? ?? false,
      offlineId: json['offline_id'] as String?,
      syncedAt: json['synced_at'] == null
          ? null
          : DateTime.parse(json['synced_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      forms: json['forms'] as Map<String, dynamic>?,
      profiles: json['profiles'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$SubmissionModelImplToJson(
        _$SubmissionModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'form_id': instance.formId,
      'submitted_by': instance.submittedBy,
      'governorate_id': instance.governorateId,
      'district_id': instance.districtId,
      'status': instance.status,
      'data': instance.data,
      'gps_lat': instance.gpsLat,
      'gps_lng': instance.gpsLng,
      'gps_accuracy': instance.gpsAccuracy,
      'photos': instance.photos,
      'notes': instance.notes,
      'reviewed_by': instance.reviewedBy,
      'reviewed_at': instance.reviewedAt?.toIso8601String(),
      'review_notes': instance.reviewNotes,
      'submitted_at': instance.submittedAt?.toIso8601String(),
      'device_id': instance.deviceId,
      'app_version': instance.appVersion,
      'is_offline': instance.isOffline,
      'offline_id': instance.offlineId,
      'synced_at': instance.syncedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'forms': instance.forms,
      'profiles': instance.profiles,
    };
