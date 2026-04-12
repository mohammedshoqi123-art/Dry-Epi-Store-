// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FormModelImpl _$$FormModelImplFromJson(Map<String, dynamic> json) =>
    _$FormModelImpl(
      id: json['id'] as String,
      titleAr: json['title_ar'] as String,
      titleEn: json['title_en'] as String,
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
      schema: json['schema'] as Map<String, dynamic>,
      version: (json['version'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      requiresGps: json['requires_gps'] as bool? ?? false,
      requiresPhoto: json['requires_photo'] as bool? ?? false,
      maxPhotos: (json['max_photos'] as num?)?.toInt() ?? 5,
      allowedRoles: (json['allowed_roles'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$FormModelImplToJson(_$FormModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title_ar': instance.titleAr,
      'title_en': instance.titleEn,
      'description_ar': instance.descriptionAr,
      'description_en': instance.descriptionEn,
      'schema': instance.schema,
      'version': instance.version,
      'is_active': instance.isActive,
      'requires_gps': instance.requiresGps,
      'requires_photo': instance.requiresPhoto,
      'max_photos': instance.maxPhotos,
      'allowed_roles': instance.allowedRoles,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

_$FormFieldImpl _$$FormFieldImplFromJson(Map<String, dynamic> json) =>
    _$FormFieldImpl(
      key: json['key'] as String,
      type: json['type'] as String,
      labelAr: json['label_ar'] as String,
      labelEn: json['label_en'] as String?,
      required: json['required'] as bool? ?? false,
      hint: json['hint'] as String?,
      defaultValue: json['defaultValue'],
      options: json['options'] as List<dynamic>?,
      min: json['min'],
      max: json['max'],
      pattern: json['pattern'] as String?,
      validation: json['validation'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$FormFieldImplToJson(_$FormFieldImpl instance) =>
    <String, dynamic>{
      'key': instance.key,
      'type': instance.type,
      'label_ar': instance.labelAr,
      'label_en': instance.labelEn,
      'required': instance.required,
      'hint': instance.hint,
      'defaultValue': instance.defaultValue,
      'options': instance.options,
      'min': instance.min,
      'max': instance.max,
      'pattern': instance.pattern,
      'validation': instance.validation,
    };
