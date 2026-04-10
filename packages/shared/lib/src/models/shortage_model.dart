import 'package:freezed_annotation/freezed_annotation.dart';

part 'shortage_model.freezed.dart';
part 'shortage_model.g.dart';

@freezed
class ShortageModel with _$ShortageModel {
  const factory ShortageModel({
    required String id,
    @JsonKey(name: 'submission_id') String? submissionId,
    @JsonKey(name: 'reported_by') required String reportedBy,
    @JsonKey(name: 'governorate_id') String? governorateId,
    @JsonKey(name: 'district_id') String? districtId,
    @JsonKey(name: 'item_name') required String itemName,
    @JsonKey(name: 'item_category') String? itemCategory,
    @JsonKey(name: 'quantity_needed') int? quantityNeeded,
    @JsonKey(name: 'quantity_available') @Default(0) int quantityAvailable,
    @Default('unit') String unit,
    @Default('medium') String severity,
    String? notes,
    @JsonKey(name: 'is_resolved') @Default(false) bool isResolved,
    @JsonKey(name: 'resolved_at') DateTime? resolvedAt,
    @JsonKey(name: 'resolved_by') String? resolvedBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    // Relations
    Map<String, dynamic>? governorates,
    Map<String, dynamic>? districts,
    Map<String, dynamic>? profiles,
  }) = _ShortageModel;

  factory ShortageModel.fromJson(Map<String, dynamic> json) => _$ShortageModelFromJson(json);
}
