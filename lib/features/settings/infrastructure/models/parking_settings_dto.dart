import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/parking_settings.dart';

part 'parking_settings_dto.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ParkingSettingsDto {
  const ParkingSettingsDto({
    required this.name,
    required this.address,
    required this.schedule,
    required this.phone,
    required this.website,
    required this.whatsapp,
    this.logoVersion = 0,
    this.evidenceRetentionDays = 0,
    this.whatsappAuto = false,
    this.carCapacity = 0,
    this.motoCapacity = 0,
    this.keyCapacity = 0,
    this.carOutOfService = 0,
    this.motoOutOfService = 0,
    this.legalPolicy = '',
    this.currency = 'COP',
  });

  factory ParkingSettingsDto.fromJson(Map<String, dynamic> json) =>
      _$ParkingSettingsDtoFromJson(json);

  final String name;
  final String address;
  final String schedule;
  final String phone;
  final String website;
  final String whatsapp;
  final int logoVersion;
  final int evidenceRetentionDays;
  final bool whatsappAuto;
  final int carCapacity;
  final int motoCapacity;
  final int keyCapacity;
  final int carOutOfService;
  final int motoOutOfService;
  final String legalPolicy;
  final String currency;

  Map<String, dynamic> toJson() => _$ParkingSettingsDtoToJson(this);

  ParkingSettings toDomain() => ParkingSettings(
    name: name,
    address: address,
    schedule: schedule,
    phone: phone,
    website: website,
    whatsapp: whatsapp,
    logoVersion: logoVersion,
    evidenceRetentionDays: evidenceRetentionDays,
    whatsappAuto: whatsappAuto,
    carCapacity: carCapacity,
    motoCapacity: motoCapacity,
    keyCapacity: keyCapacity,
    carOutOfService: carOutOfService,
    motoOutOfService: motoOutOfService,
    legalPolicy: legalPolicy,
    currency: currency,
  );
}
