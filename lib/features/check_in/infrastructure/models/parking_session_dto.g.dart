// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parking_session_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ParkingSessionDto _$ParkingSessionDtoFromJson(Map<String, dynamic> json) =>
    ParkingSessionDto(
      id: (json['id'] as num).toInt(),
      plate: json['plate'] as String,
      status: json['status'] as String,
      entryTime: DateTime.parse(json['entry_time'] as String),
      photoCount: (json['photo_count'] as num).toInt(),
    );

Map<String, dynamic> _$ParkingSessionDtoToJson(ParkingSessionDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'plate': instance.plate,
      'status': instance.status,
      'entry_time': instance.entryTime.toIso8601String(),
      'photo_count': instance.photoCount,
    };
