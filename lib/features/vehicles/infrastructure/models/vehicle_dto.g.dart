// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VehicleDto _$VehicleDtoFromJson(Map<String, dynamic> json) => VehicleDto(
  id: (json['id'] as num?)?.toInt(),
  plate: json['plate'] as String,
  categoryId: (json['category_id'] as num).toInt(),
  color: json['color'] as String?,
  brand: json['brand'] as String?,
);

Map<String, dynamic> _$VehicleDtoToJson(VehicleDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'plate': instance.plate,
      'category_id': instance.categoryId,
      'color': instance.color,
      'brand': instance.brand,
    };
