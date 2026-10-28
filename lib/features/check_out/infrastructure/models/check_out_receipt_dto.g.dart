// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_out_receipt_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CheckOutReceiptDto _$CheckOutReceiptDtoFromJson(Map<String, dynamic> json) =>
    CheckOutReceiptDto(
      id: (json['id'] as num).toInt(),
      plate: json['plate'] as String,
      entryTime: DateTime.parse(json['entry_time'] as String),
      exitTime: DateTime.parse(json['exit_time'] as String),
      amountCharged: (json['amount_charged'] as num).toInt(),
      ticketNumber: json['ticket_number'] as String,
      paymentMethod: json['payment_method'] as String?,
      cardType: json['card_type'] as String?,
      cashReceived: (json['cash_received'] as num?)?.toInt(),
      cashChange: (json['cash_change'] as num?)?.toInt(),
      discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
      discountReason: json['discount_reason'] as String?,
      lostTicket: json['lost_ticket'] as bool? ?? false,
    );

Map<String, dynamic> _$CheckOutReceiptDtoToJson(CheckOutReceiptDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'plate': instance.plate,
      'entry_time': instance.entryTime.toIso8601String(),
      'exit_time': instance.exitTime.toIso8601String(),
      'amount_charged': instance.amountCharged,
      'ticket_number': instance.ticketNumber,
      'payment_method': instance.paymentMethod,
      'card_type': instance.cardType,
      'cash_received': instance.cashReceived,
      'cash_change': instance.cashChange,
      'discount_amount': instance.discountAmount,
      'discount_reason': instance.discountReason,
      'lost_ticket': instance.lostTicket,
    };
