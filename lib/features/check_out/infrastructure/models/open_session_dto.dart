import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/open_session.dart';

part 'open_session_dto.g.dart';

@JsonSerializable()
class OpenSessionDto {
  const OpenSessionDto({
    required this.id,
    required this.vehicleId,
    required this.entryTime,
    this.plate = '',
    this.hasPass = false,
    this.photoCount = 0,
    this.leftKeys = false,
    this.onlinePaidAmount = 0,
    this.onlineGraceUntil,
  });

  factory OpenSessionDto.fromJson(Map<String, dynamic> json) =>
      _$OpenSessionDtoFromJson(json);

  final int id;

  @JsonKey(name: 'vehicle_id')
  final int vehicleId;

  @JsonKey(name: 'entry_time')
  final DateTime entryTime;

  @JsonKey(defaultValue: '')
  final String plate;

  @JsonKey(name: 'has_pass', defaultValue: false)
  final bool hasPass;

  @JsonKey(name: 'photo_count', defaultValue: 0)
  final int photoCount;

  @JsonKey(name: 'left_keys', defaultValue: false)
  final bool leftKeys;

  @JsonKey(name: 'online_paid_amount', defaultValue: 0)
  final int onlinePaidAmount;

  @JsonKey(name: 'online_grace_until')
  final DateTime? onlineGraceUntil;

  Map<String, dynamic> toJson() => _$OpenSessionDtoToJson(this);

  OpenSession toDomain() => OpenSession(
    id: id,
    vehicleId: vehicleId,
    entryTime: entryTime,
    plate: plate,
    hasPass: hasPass,
    photoCount: photoCount,
    leftKeys: leftKeys,
    onlinePaidAmount: onlinePaidAmount,
    onlineGraceUntil: onlineGraceUntil,
  );
}
