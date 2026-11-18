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
      coverPath: json['cover_path'] as String? ?? '',
      coverVersion: (json['cover_version'] as num?)?.toInt() ?? 0,
      evidenceRetentionDays:
          (json['evidence_retention_days'] as num?)?.toInt() ?? 0,
      reservationGraceMinutes:
          (json['reservation_grace_minutes'] as num?)?.toInt() ?? 15,
      whatsappAuto: json['whatsapp_auto'] as bool? ?? false,
      carCapacity: (json['car_capacity'] as num?)?.toInt() ?? 0,
      motoCapacity: (json['moto_capacity'] as num?)?.toInt() ?? 0,
      keyCapacity: (json['key_capacity'] as num?)?.toInt() ?? 0,
      carOutOfService: (json['car_out_of_service'] as num?)?.toInt() ?? 0,
      motoOutOfService: (json['moto_out_of_service'] as num?)?.toInt() ?? 0,
      legalPolicy: json['legal_policy'] as String? ?? '',
      currency: json['currency'] as String? ?? 'COP',
      minAppVersion: json['min_app_version'] as String? ?? '',
      policePhone: json['police_phone'] as String? ?? '',
      onlinePaymentsEnabled: json['online_payments_enabled'] as bool? ?? false,
      onlinePaymentGraceMinutes:
          (json['online_payment_grace_minutes'] as num?)?.toInt() ?? 15,
      onlinePaymentMinAmount:
          (json['online_payment_min_amount'] as num?)?.toInt() ?? 1500,
      passRenewalEnabled: json['pass_renewal_enabled'] as bool? ?? false,
      passRenewalPaymentLinks:
          json['pass_renewal_payment_links'] as bool? ?? false,
      passRenewalCadence: json['pass_renewal_cadence'] as String? ?? '7,3,1',
      version: (json['version'] as num?)?.toInt() ?? 0,
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
      'cover_path': instance.coverPath,
      'cover_version': instance.coverVersion,
      'evidence_retention_days': instance.evidenceRetentionDays,
      'reservation_grace_minutes': instance.reservationGraceMinutes,
      'whatsapp_auto': instance.whatsappAuto,
      'car_capacity': instance.carCapacity,
      'moto_capacity': instance.motoCapacity,
      'key_capacity': instance.keyCapacity,
      'car_out_of_service': instance.carOutOfService,
      'moto_out_of_service': instance.motoOutOfService,
      'legal_policy': instance.legalPolicy,
      'currency': instance.currency,
      'min_app_version': instance.minAppVersion,
      'police_phone': instance.policePhone,
      'online_payments_enabled': instance.onlinePaymentsEnabled,
      'online_payment_grace_minutes': instance.onlinePaymentGraceMinutes,
      'online_payment_min_amount': instance.onlinePaymentMinAmount,
      'pass_renewal_enabled': instance.passRenewalEnabled,
      'pass_renewal_payment_links': instance.passRenewalPaymentLinks,
      'pass_renewal_cadence': instance.passRenewalCadence,
      'version': instance.version,
    };
