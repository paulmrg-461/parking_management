import 'package:equatable/equatable.dart';

/// A charge created when a monthly pass is issued (manual or auto-renewed).
class MonthlyPassPayment extends Equatable {
  const MonthlyPassPayment({
    required this.id,
    required this.monthlyPassId,
    required this.vehicleId,
    required this.plate,
    required this.startDate,
    required this.endDate,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.dueDate,
  });

  final int id;
  final int monthlyPassId;
  final int vehicleId;
  final String plate;
  final DateTime startDate;
  final DateTime endDate;
  final int amount;
  final String paymentMethod;
  final String status;
  final DateTime dueDate;

  bool get isPending => status == 'pending';

  factory MonthlyPassPayment.fromJson(Map<String, dynamic> json) =>
      MonthlyPassPayment(
        id: (json['id'] as num).toInt(),
        monthlyPassId: (json['monthly_pass_id'] as num).toInt(),
        vehicleId: (json['vehicle_id'] as num).toInt(),
        plate: json['plate'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        amount: (json['amount'] as num).toInt(),
        paymentMethod: json['payment_method'] as String? ?? 'cash',
        status: json['status'] as String,
        dueDate: DateTime.parse(json['due_date'] as String),
      );

  @override
  List<Object?> get props => [
    id,
    monthlyPassId,
    vehicleId,
    plate,
    startDate,
    endDate,
    amount,
    paymentMethod,
    status,
    dueDate,
  ];
}
