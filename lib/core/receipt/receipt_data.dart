import '../fare/fare_adjustment.dart';

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
    this.cardType,
    this.cashReceived,
    this.cashChange,
    this.discountAmount = 0,
    this.discountReason,
    this.onlinePaidAmount = 0,
    this.grossAmount,
    this.adjustments = const [],
    this.pricingLabel,
    this.pricingDelta = 0,
    this.pendingSync = false,
    this.evidenceUrl,
    this.feedbackUrl,
  });

  final ReceiptKind kind;
  final String plate;
  final DateTime entryTime;
  final DateTime? exitTime;
  final int? photoCount;
  final int? amountCharged;
  final String? ticketNumber;
  final String? paymentMethod;
  final String? cardType;

  /// Cash handed over and change given (cash payments only).
  final int? cashReceived;
  final int? cashChange;
  final int discountAmount;
  final String? discountReason;

  /// Part of the charge the customer already paid online (0 = none). The
  /// session's `amount_charged` already includes it.
  final int onlinePaidAmount;

  /// Fare before the automatic lines and the manual discount.
  final int? grossAmount;

  /// Merchant (and later reward) reductions applied by the server.
  final List<FareAdjustment> adjustments;

  /// Formatted dynamic-pricing label (built by the feature, never here).
  final String? pricingLabel;

  /// Signed difference of the locked rate against the base fare.
  final int pricingDelta;
  final bool pendingSync;

  /// Public page (plate is the key) with the session's photos and videos.
  final String? evidenceUrl;

  /// Public survey page for this visit (check-out receipts only).
  final String? feedbackUrl;

  bool get isCheckOut => kind == ReceiptKind.checkOut;
}
