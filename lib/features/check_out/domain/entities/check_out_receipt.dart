import 'package:equatable/equatable.dart';

/// The receipt returned when a parking session is closed via check-out.
class CheckOutReceipt extends Equatable {
  const CheckOutReceipt({
    required this.id,
    required this.plate,
    required this.entryTime,
    required this.exitTime,
    required this.amountCharged,
    required this.ticketNumber,
  });

  final int id;
  final String plate;
  final DateTime entryTime;
  final DateTime exitTime;
  final int amountCharged;
  final String ticketNumber;

  @override
  List<Object?> get props =>
      [id, plate, entryTime, exitTime, amountCharged, ticketNumber];
}
