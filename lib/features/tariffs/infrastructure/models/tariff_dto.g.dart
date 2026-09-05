// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tariff_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TariffDto _$TariffDtoFromJson(Map<String, dynamic> json) => TariffDto(
  id: (json['id'] as num?)?.toInt(),
  categoryId: (json['category_id'] as num).toInt(),
  type: json['type'] as String,
  amount: (json['amount'] as num).toInt(),
  startTime: json['start_time'] as String?,
  endTime: json['end_time'] as String?,
  active: json['active'] as bool? ?? true,
);

Map<String, dynamic> _$TariffDtoToJson(TariffDto instance) => <String, dynamic>{
  'id': instance.id,
  'category_id': instance.categoryId,
  'type': instance.type,
  'amount': instance.amount,
  'start_time': instance.startTime,
  'end_time': instance.endTime,
  'active': instance.active,
};
