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
      evidenceRetentionDays:
          (json['evidence_retention_days'] as num?)?.toInt() ?? 0,
      whatsappAuto: json['whatsapp_auto'] as bool? ?? false,
      carCapacity: (json['car_capacity'] as num?)?.toInt() ?? 0,
      motoCapacity: (json['moto_capacity'] as num?)?.toInt() ?? 0,
      keyCapacity: (json['key_capacity'] as num?)?.toInt() ?? 0,
      carOutOfService: (json['car_out_of_service'] as num?)?.toInt() ?? 0,
      motoOutOfService: (json['moto_out_of_service'] as num?)?.toInt() ?? 0,
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
      'evidence_retention_days': instance.evidenceRetentionDays,
      'whatsapp_auto': instance.whatsappAuto,
      'car_capacity': instance.carCapacity,
      'moto_capacity': instance.motoCapacity,
      'key_capacity': instance.keyCapacity,
      'car_out_of_service': instance.carOutOfService,
      'moto_out_of_service': instance.motoOutOfService,
    };
