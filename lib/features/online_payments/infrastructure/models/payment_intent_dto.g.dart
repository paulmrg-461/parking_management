// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_intent_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentIntentDto _$PaymentIntentDtoFromJson(Map<String, dynamic> json) =>
    PaymentIntentDto(
      intentId: (json['intent_id'] as num).toInt(),
      reference: json['reference'] as String,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      checkoutUrl: json['checkout_url'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      graceMinutes: (json['grace_minutes'] as num?)?.toInt() ?? 15,
    );

Map<String, dynamic> _$PaymentIntentDtoToJson(PaymentIntentDto instance) =>
    <String, dynamic>{
      'intent_id': instance.intentId,
      'reference': instance.reference,
      'amount': instance.amount,
      'currency': instance.currency,
      'checkout_url': instance.checkoutUrl,
      'expires_at': instance.expiresAt.toIso8601String(),
      'grace_minutes': instance.graceMinutes,
    };
