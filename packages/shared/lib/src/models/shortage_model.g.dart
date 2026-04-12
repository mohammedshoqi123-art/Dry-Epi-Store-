// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shortage_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShortageModelImpl _$$ShortageModelImplFromJson(Map<String, dynamic> json) =>
    _$ShortageModelImpl(
      id: json['id'] as String,
      submissionId: json['submission_id'] as String?,
      reportedBy: json['reported_by'] as String,
      governorateId: json['governorate_id'] as String?,
      districtId: json['district_id'] as String?,
      itemName: json['item_name'] as String,
      itemCategory: json['item_category'] as String?,
      quantityNeeded: (json['quantity_needed'] as num?)?.toInt(),
      quantityAvailable: (json['quantity_available'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String? ?? 'unit',
      severity: json['severity'] as String? ?? 'medium',
      notes: json['notes'] as String?,
      isResolved: json['is_resolved'] as bool? ?? false,
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      resolvedBy: json['resolved_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      governorates: json['governorates'] as Map<String, dynamic>?,
      districts: json['districts'] as Map<String, dynamic>?,
      profiles: json['profiles'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$ShortageModelImplToJson(_$ShortageModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'submission_id': instance.submissionId,
      'reported_by': instance.reportedBy,
      'governorate_id': instance.governorateId,
      'district_id': instance.districtId,
      'item_name': instance.itemName,
      'item_category': instance.itemCategory,
      'quantity_needed': instance.quantityNeeded,
      'quantity_available': instance.quantityAvailable,
      'unit': instance.unit,
      'severity': instance.severity,
      'notes': instance.notes,
      'is_resolved': instance.isResolved,
      'resolved_at': instance.resolvedAt?.toIso8601String(),
      'resolved_by': instance.resolvedBy,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'governorates': instance.governorates,
      'districts': instance.districts,
      'profiles': instance.profiles,
    };
