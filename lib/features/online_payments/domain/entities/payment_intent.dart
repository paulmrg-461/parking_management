import 'package:equatable/equatable.dart';

/// A frozen amount the customer is about to pay with the gateway.
class PaymentIntent extends Equatable {
  const PaymentIntent({
    required this.intentId,
    required this.reference,
    required this.amount,
    required this.currency,
    required this.checkoutUrl,
    required this.expiresAt,
    this.graceMinutes = 15,
  });

  final int intentId;
  final String reference;

  /// Amount in the lot currency's minor unit, computed server-side.
  final int amount;
  final String currency;
  final String checkoutUrl;
  final DateTime expiresAt;

  /// Minutes to leave the lot after the gateway approves the payment.
  final int graceMinutes;

  factory PaymentIntent.fromJson(Map<String, dynamic> json) => PaymentIntent(
    intentId: (json['intent_id'] as num?)?.toInt() ?? 0,
    reference: json['reference'] as String? ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    currency: json['currency'] as String? ?? 'COP',
    checkoutUrl: json['checkout_url'] as String? ?? '',
    expiresAt:
        DateTime.tryParse(json['expires_at'] as String? ?? '') ??
        DateTime.now(),
    graceMinutes: (json['grace_minutes'] as num?)?.toInt() ?? 15,
  );

  @override
  List<Object?> get props => [
    intentId,
    reference,
    amount,
    currency,
    checkoutUrl,
    expiresAt,
    graceMinutes,
  ];
}
