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

  Map<String, dynamic> toJson() => _$ParkingSettingsDtoToJson(this);

  ParkingSettings toDomain() => ParkingSettings(
    name: name,
    address: address,
    schedule: schedule,
    phone: phone,
    website: website,
    whatsapp: whatsapp,
    logoVersion: logoVersion,
  );
}
