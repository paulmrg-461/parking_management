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
    this.paymentMethod,
    this.discountAmount = 0,
    this.discountReason,
    this.pendingSync = false,
    this.evidenceUrl,
  });

  final ReceiptKind kind;
  final String plate;
  final DateTime entryTime;
  final DateTime? exitTime;
  final int? photoCount;
  final int? amountCharged;
  final String? ticketNumber;
  final String? paymentMethod;
  final int discountAmount;
  final String? discountReason;
  final bool pendingSync;

  /// Public page (plate is the key) with the session's photos and videos.
  final String? evidenceUrl;

  bool get isCheckOut => kind == ReceiptKind.checkOut;
}
