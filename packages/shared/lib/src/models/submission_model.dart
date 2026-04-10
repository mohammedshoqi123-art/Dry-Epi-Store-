import 'package:freezed_annotation/freezed_annotation.dart';

part 'submission_model.freezed.dart';
part 'submission_model.g.dart';

@freezed
class SubmissionModel with _$SubmissionModel {
  const factory SubmissionModel({
    required String id,
    @JsonKey(name: 'form_id') required String formId,
    @JsonKey(name: 'submitted_by') required String submittedBy,
    @JsonKey(name: 'governorate_id') String? governorateId,
    @JsonKey(name: 'district_id') String? districtId,
    @Default('draft') String status,
    @Default({}) Map<String, dynamic> data,
    @JsonKey(name: 'gps_lat') double? gpsLat,
    @JsonKey(name: 'gps_lng') double? gpsLng,
    @JsonKey(name: 'gps_accuracy') double? gpsAccuracy,
    @Default([]) List<String> photos,
    String? notes,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'review_notes') String? reviewNotes,
    @JsonKey(name: 'submitted_at') DateTime? submittedAt,
    @JsonKey(name: 'device_id') String? deviceId,
    @JsonKey(name: 'app_version') String? appVersion,
    @JsonKey(name: 'is_offline') @Default(false) bool isOffline,
    @JsonKey(name: 'offline_id') String? offlineId,
    @JsonKey(name: 'synced_at') DateTime? syncedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    // Relations
    Map<String, dynamic>? forms,
    Map<String, dynamic>? profiles,
  }) = _SubmissionModel;

  factory SubmissionModel.fromJson(Map<String, dynamic> json) => _$SubmissionModelFromJson(json);
}
