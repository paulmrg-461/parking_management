import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/open_session.dart';

part 'open_session_dto.g.dart';

@JsonSerializable()
class OpenSessionDto {
  const OpenSessionDto({
    required this.id,
    required this.vehicleId,
    required this.entryTime,
  });

  factory OpenSessionDto.fromJson(Map<String, dynamic> json) =>
      _$OpenSessionDtoFromJson(json);

  final int id;

  @JsonKey(name: 'vehicle_id')
  final int vehicleId;

  @JsonKey(name: 'entry_time')
  final DateTime entryTime;

  Map<String, dynamic> toJson() => _$OpenSessionDtoToJson(this);

  OpenSession toDomain() => OpenSession(
        id: id,
        vehicleId: vehicleId,
        entryTime: entryTime,
      );
}
