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
  });

  factory ParkingSessionDto.fromJson(Map<String, dynamic> json) =>
      _$ParkingSessionDtoFromJson(json);

  final int id;
  final String plate;
  final String status;

  @JsonKey(name: 'entry_time')
  final DateTime entryTime;

  @JsonKey(name: 'photo_count')
  final int photoCount;

  Map<String, dynamic> toJson() => _$ParkingSessionDtoToJson(this);

  ParkingSession toDomain() => ParkingSession(
        id: id,
        plate: plate,
        status: status == 'closed'
            ? ParkingSessionStatus.closed
            : ParkingSessionStatus.open,
        entryTime: entryTime,
        photoCount: photoCount,
      );
}
