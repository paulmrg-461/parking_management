import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/monthly_pass.dart';

part 'monthly_pass_dto.g.dart';

@JsonSerializable()
class MonthlyPassDto {
  const MonthlyPassDto({
    this.id,
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.amount,
    this.active = true,
  });

  factory MonthlyPassDto.fromJson(Map<String, dynamic> json) =>
      _$MonthlyPassDtoFromJson(json);

  final int? id;

  @JsonKey(name: 'vehicle_id')
  final int vehicleId;

  @JsonKey(name: 'start_date')
  final DateTime startDate;

  @JsonKey(name: 'end_date')
  final DateTime endDate;

  final int amount;
  final bool active;

  Map<String, dynamic> toJson() => _$MonthlyPassDtoToJson(this);

  MonthlyPass toDomain() => MonthlyPass(
        id: id,
        vehicleId: vehicleId,
        startDate: startDate,
        endDate: endDate,
        amount: amount,
        active: active,
      );
}
