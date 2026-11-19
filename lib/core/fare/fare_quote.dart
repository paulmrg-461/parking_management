import 'package:equatable/equatable.dart';

import 'fare_adjustment.dart';

/// What a session owes at a given instant (`rpc/fare_quote`): the base fare,
/// the merchant/reward lines and the manual discount. Billing math is
/// backend-only; this is a read model.
class FareQuote extends Equatable {
  const FareQuote({
    required this.sessionId,
    required this.baseAmount,
    required this.gross,
    this.hasPass = false,
    this.lostTicket = false,
    this.adjustments = const [],
    this.adjustmentsTotal = 0,
    this.discountAmount = 0,
    this.amountDue = 0,
    this.pricing,
    this.reward,
  });

  final int sessionId;

  /// Fare before pricing and benefits.
  final int baseAmount;

  /// Fare after pricing (a price change, not a discount), before benefits.
  final int gross;
  final bool hasPass;
  final bool lostTicket;
  final List<FareAdjustment> adjustments;
  final int adjustmentsTotal;

  /// Manual admin discount (never the automatic lines).
  final int discountAmount;

  /// What the customer owes after lines and discount.
  final int amountDue;

  /// Raw maps: the pricing/reward changes add their own parsers.
  final Map<String, Object?>? pricing;
  final Map<String, Object?>? reward;

  factory FareQuote.fromJson(Map<String, dynamic> json) => FareQuote(
    sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
    baseAmount: (json['base_amount'] as num?)?.toInt() ?? 0,
    gross: (json['gross'] as num?)?.toInt() ?? 0,
    hasPass: json['has_pass'] as bool? ?? false,
    lostTicket: json['lost_ticket'] as bool? ?? false,
    adjustments: FareAdjustment.listFromJson(json['adjustments']),
    adjustmentsTotal: (json['adjustments_total'] as num?)?.toInt() ?? 0,
    discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
    amountDue: (json['amount_due'] as num?)?.toInt() ?? 0,
    pricing: json['pricing'] is Map
        ? Map<String, Object?>.from(json['pricing'] as Map)
        : null,
    reward: json['reward'] is Map
        ? Map<String, Object?>.from(json['reward'] as Map)
        : null,
  );

  @override
  List<Object?> get props => [
    sessionId,
    baseAmount,
    gross,
    hasPass,
    lostTicket,
    adjustments,
    adjustmentsTotal,
    discountAmount,
    amountDue,
    pricing,
    reward,
  ];
}
