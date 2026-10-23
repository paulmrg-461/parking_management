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
    this.autoRenew = false,
    this.autoRenewPaymentMethod = 'cash',
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

  @JsonKey(name: 'auto_renew')
  final bool autoRenew;

  @JsonKey(name: 'auto_renew_payment_method')
  final String autoRenewPaymentMethod;

  Map<String, dynamic> toJson() => _$MonthlyPassDtoToJson(this);

  MonthlyPass toDomain() => MonthlyPass(
        id: id,
        vehicleId: vehicleId,
        startDate: startDate,
        endDate: endDate,
        amount: amount,
        active: active,
        autoRenew: autoRenew,
        autoRenewPaymentMethod: autoRenewPaymentMethod,
      );
}
