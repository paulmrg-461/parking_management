import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/payment_intent.dart';

part 'payment_intent_dto.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class PaymentIntentDto {
  const PaymentIntentDto({
    required this.intentId,
    required this.reference,
    required this.amount,
    required this.currency,
    required this.checkoutUrl,
    required this.expiresAt,
    this.graceMinutes = 15,
  });

  factory PaymentIntentDto.fromJson(Map<String, dynamic> json) =>
      _$PaymentIntentDtoFromJson(json);

  final int intentId;
  final String reference;
  final int amount;
  final String currency;
  final String checkoutUrl;
  final DateTime expiresAt;
  final int graceMinutes;

  Map<String, dynamic> toJson() => _$PaymentIntentDtoToJson(this);

  PaymentIntent toDomain() => PaymentIntent(
    intentId: intentId,
    reference: reference,
    amount: amount,
    currency: currency,
    checkoutUrl: checkoutUrl,
    expiresAt: expiresAt,
    graceMinutes: graceMinutes,
  );
}
