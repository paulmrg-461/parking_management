// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_session_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenSessionDto _$OpenSessionDtoFromJson(Map<String, dynamic> json) =>
    OpenSessionDto(
      id: (json['id'] as num).toInt(),
      vehicleId: (json['vehicle_id'] as num).toInt(),
      entryTime: DateTime.parse(json['entry_time'] as String),
    );

Map<String, dynamic> _$OpenSessionDtoToJson(OpenSessionDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'vehicle_id': instance.vehicleId,
      'entry_time': instance.entryTime.toIso8601String(),
    };
