import 'package:equatable/equatable.dart';

class MonthlyPass extends Equatable {
  const MonthlyPass({
    this.id,
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.amount,
    this.active = true,
    this.autoRenew = false,
  });

  final int? id;
  final int vehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final int amount;
  final bool active;
  final bool autoRenew;

  @override
  List<Object?> get props =>
      [id, vehicleId, startDate, endDate, amount, active, autoRenew];
}
