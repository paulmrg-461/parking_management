import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/open_session.dart';

part 'open_session_dto.g.dart';

@JsonSerializable()
class OpenSessionDto {
  const OpenSessionDto({
    required this.id,
    required this.vehicleId,
    required this.entryTime,
    this.hasPass = false,
    this.photoCount = 0,
    this.leftKeys = false,
  });

  factory OpenSessionDto.fromJson(Map<String, dynamic> json) =>
      _$OpenSessionDtoFromJson(json);

  final int id;

  @JsonKey(name: 'vehicle_id')
  final int vehicleId;

  @JsonKey(name: 'entry_time')
  final DateTime entryTime;

  @JsonKey(name: 'has_pass', defaultValue: false)
  final bool hasPass;

  @JsonKey(name: 'photo_count', defaultValue: 0)
  final int photoCount;

  @JsonKey(name: 'left_keys', defaultValue: false)
  final bool leftKeys;

  Map<String, dynamic> toJson() => _$OpenSessionDtoToJson(this);

  OpenSession toDomain() => OpenSession(
    id: id,
    vehicleId: vehicleId,
    entryTime: entryTime,
    hasPass: hasPass,
  );
}
