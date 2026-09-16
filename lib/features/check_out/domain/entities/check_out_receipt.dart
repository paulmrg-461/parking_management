import 'package:equatable/equatable.dart';

/// The receipt returned when a parking session is closed via check-out.
///
/// When [pendingSync] is `true` (the check-out was queued offline, see
/// `CheckOutRepositoryImpl`), [amountCharged] and [ticketNumber] are `null`:
/// billing math is backend-only, so no amount is ever guessed client-side.
class CheckOutReceipt extends Equatable {
  const CheckOutReceipt({
    required this.id,
    required this.plate,
    required this.entryTime,
    required this.exitTime,
    required this.amountCharged,
    required this.ticketNumber,
    this.pendingSync = false,
  });

  final int id;
  final String plate;
  final DateTime entryTime;
  final DateTime exitTime;
  final int? amountCharged;
  final String? ticketNumber;
  final bool pendingSync;

  @override
  List<Object?> get props =>
      [id, plate, entryTime, exitTime, amountCharged, ticketNumber, pendingSync];
}
