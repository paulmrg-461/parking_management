/// Whether a receipt describes a vehicle entering or leaving.
enum ReceiptKind { checkIn, checkOut }

/// Display/print data for a receipt. Pure UI-agnostic model: it is built from
/// a `CheckOutReceipt` or a `ParkingSession` at the call site and consumed by
/// both the on-screen receipt card and the print adapters.
class ReceiptData {
  const ReceiptData({
    required this.kind,
    required this.plate,
    required this.entryTime,
    this.exitTime,
    this.photoCount,
    this.amountCharged,
    this.ticketNumber,
    this.pendingSync = false,
  });

  final ReceiptKind kind;
  final String plate;
  final DateTime entryTime;
  final DateTime? exitTime;
  final int? photoCount;
  final int? amountCharged;
  final String? ticketNumber;
  final bool pendingSync;

  bool get isCheckOut => kind == ReceiptKind.checkOut;
}
