// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_pass_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MonthlyPassDto _$MonthlyPassDtoFromJson(Map<String, dynamic> json) =>
    MonthlyPassDto(
      id: (json['id'] as num?)?.toInt(),
      vehicleId: (json['vehicle_id'] as num).toInt(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      amount: (json['amount'] as num).toInt(),
      active: json['active'] as bool? ?? true,
    );

Map<String, dynamic> _$MonthlyPassDtoToJson(MonthlyPassDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'vehicle_id': instance.vehicleId,
      'start_date': instance.startDate.toIso8601String(),
      'end_date': instance.endDate.toIso8601String(),
      'amount': instance.amount,
      'active': instance.active,
    };
