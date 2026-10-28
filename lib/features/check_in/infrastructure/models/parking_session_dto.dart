import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/parking_session.dart';

part 'parking_session_dto.g.dart';

@JsonSerializable()
class ParkingSessionDto {
  const ParkingSessionDto({
    required this.id,
    required this.plate,
    required this.status,
    required this.entryTime,
    required this.photoCount,
    this.leftKeys = false,
    this.spotId,
    this.spotCode,
    this.videoCount = 0,
  });

  factory ParkingSessionDto.fromJson(Map<String, dynamic> json) =>
      _$ParkingSessionDtoFromJson(json);

  final int id;
  final String plate;
  final String status;

  @JsonKey(name: 'entry_time')
  final DateTime entryTime;

  @JsonKey(name: 'left_keys', defaultValue: false)
  final bool leftKeys;

  @JsonKey(name: 'photo_count')
  final int photoCount;

  @JsonKey(name: 'spot_id')
  final int? spotId;

  @JsonKey(name: 'spot_code')
  final String? spotCode;

  @JsonKey(name: 'video_count', defaultValue: 0)
  final int videoCount;

  Map<String, dynamic> toJson() => _$ParkingSessionDtoToJson(this);

  ParkingSession toDomain() => ParkingSession(
        id: id,
        plate: plate,
        status: status == 'closed'
            ? ParkingSessionStatus.closed
            : ParkingSessionStatus.open,
        entryTime: entryTime,
        photoCount: photoCount,
        leftKeys: leftKeys,
        spotId: spotId,
        spotCode: spotCode,
        videoCount: videoCount,
      );
}
