import 'package:equatable/equatable.dart';

class MonthlyPass extends Equatable {
  const MonthlyPass({
    this.id,
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.amount,
    this.active = true,
  });

  final int? id;
  final int vehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final int amount;
  final bool active;

  @override
  List<Object?> get props =>
      [id, vehicleId, startDate, endDate, amount, active];
}
