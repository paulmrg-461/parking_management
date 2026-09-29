// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parking_settings_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ParkingSettingsDto _$ParkingSettingsDtoFromJson(Map<String, dynamic> json) =>
    ParkingSettingsDto(
      name: json['name'] as String,
      address: json['address'] as String,
      schedule: json['schedule'] as String,
      phone: json['phone'] as String,
      website: json['website'] as String,
      whatsapp: json['whatsapp'] as String,
      logoVersion: (json['logo_version'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ParkingSettingsDtoToJson(ParkingSettingsDto instance) =>
    <String, dynamic>{
      'name': instance.name,
      'address': instance.address,
      'schedule': instance.schedule,
      'phone': instance.phone,
      'website': instance.website,
      'whatsapp': instance.whatsapp,
      'logo_version': instance.logoVersion,
    };
