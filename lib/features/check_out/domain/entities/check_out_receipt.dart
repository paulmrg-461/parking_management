import 'package:equatable/equatable.dart';

import '../../../../core/fare/fare_adjustment.dart';
import '../../../pricing/domain/entities/fare_pricing.dart';

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
    this.paymentMethod = 'cash',
    this.cardType,
    this.cashReceived,
    this.cashChange,
    this.discountAmount = 0,
    this.discountReason,
    this.lostTicket = false,
    this.pendingSync = false,
    this.onlinePaidAmount = 0,
    this.grossAmount,
    this.adjustments = const [],
    this.pricing,
  });

  final int id;
  final String plate;
  final DateTime entryTime;
  final DateTime exitTime;
  final int? amountCharged;
  final String? ticketNumber;
  final String paymentMethod;
  final String? cardType;
  final int? cashReceived;
  final int? cashChange;
  final int discountAmount;
  final String? discountReason;
  final bool lostTicket;
  final bool pendingSync;

  /// Part of `amountCharged` the customer paid online (0 = none).
  final int onlinePaidAmount;

  /// Fare before the automatic lines and the manual discount.
  final int? grossAmount;

  /// Merchant (and later reward) lines applied by the server.
  final List<FareAdjustment> adjustments;

  /// Locked dynamic-pricing rule (null without one).
  final FarePricing? pricing;

  @override
  List<Object?> get props => [
    id,
    plate,
    entryTime,
    exitTime,
    amountCharged,
    ticketNumber,
    paymentMethod,
    cardType,
    cashReceived,
    cashChange,
    discountAmount,
    discountReason,
    lostTicket,
    pendingSync,
    onlinePaidAmount,
    grossAmount,
    adjustments,
    pricing,
  ];
}
