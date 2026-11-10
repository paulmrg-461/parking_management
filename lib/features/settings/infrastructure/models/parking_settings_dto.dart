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
    this.coverPath = '',
    this.coverVersion = 0,
    this.evidenceRetentionDays = 0,
    this.reservationGraceMinutes = 15,
    this.whatsappAuto = false,
    this.carCapacity = 0,
    this.motoCapacity = 0,
    this.keyCapacity = 0,
    this.carOutOfService = 0,
    this.motoOutOfService = 0,
    this.legalPolicy = '',
    this.currency = 'COP',
    this.minAppVersion = '',
    this.policePhone = '',
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
  final String coverPath;
  final int coverVersion;
  final int evidenceRetentionDays;

  /// Minutes after `reserved_until` a hold still counts (0..120).
  final int reservationGraceMinutes;
  final bool whatsappAuto;
  final int carCapacity;
  final int motoCapacity;
  final int keyCapacity;
  final int carOutOfService;
  final int motoOutOfService;
  final String legalPolicy;
  final String currency;
  final String minAppVersion;
  final String policePhone;

  Map<String, dynamic> toJson() => _$ParkingSettingsDtoToJson(this);

  ParkingSettings toDomain() => ParkingSettings(
    name: name,
    address: address,
    schedule: schedule,
    phone: phone,
    website: website,
    whatsapp: whatsapp,
    logoVersion: logoVersion,
    coverPath: coverPath,
    coverVersion: coverVersion,
    evidenceRetentionDays: evidenceRetentionDays,
    reservationGraceMinutes: reservationGraceMinutes,
    whatsappAuto: whatsappAuto,
    carCapacity: carCapacity,
    motoCapacity: motoCapacity,
    keyCapacity: keyCapacity,
    carOutOfService: carOutOfService,
    motoOutOfService: motoOutOfService,
    legalPolicy: legalPolicy,
    currency: currency,
    minAppVersion: minAppVersion,
    policePhone: policePhone,
  );
}
