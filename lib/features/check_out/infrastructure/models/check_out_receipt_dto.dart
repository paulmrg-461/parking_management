import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/check_out_receipt.dart';

part 'check_out_receipt_dto.g.dart';

@JsonSerializable()
class CheckOutReceiptDto {
  const CheckOutReceiptDto({
    required this.id,
    required this.plate,
    required this.entryTime,
    required this.exitTime,
    required this.amountCharged,
    required this.ticketNumber,
    this.paymentMethod,
    this.cardType,
    this.cashReceived,
    this.cashChange,
    this.discountAmount = 0,
    this.discountReason,
    this.lostTicket = false,
  });

  factory CheckOutReceiptDto.fromJson(Map<String, dynamic> json) =>
      _$CheckOutReceiptDtoFromJson(json);

  final int id;
  final String plate;

  @JsonKey(name: 'entry_time')
  final DateTime entryTime;

  @JsonKey(name: 'exit_time')
  final DateTime exitTime;

  @JsonKey(name: 'amount_charged')
  final int amountCharged;

  @JsonKey(name: 'ticket_number')
  final String ticketNumber;

  @JsonKey(name: 'payment_method')
  final String? paymentMethod;

  @JsonKey(name: 'card_type')
  final String? cardType;

  @JsonKey(name: 'cash_received')
  final int? cashReceived;

  @JsonKey(name: 'cash_change')
  final int? cashChange;

  @JsonKey(name: 'discount_amount')
  final int discountAmount;

  @JsonKey(name: 'discount_reason')
  final String? discountReason;

  @JsonKey(name: 'lost_ticket', defaultValue: false)
  final bool lostTicket;

  Map<String, dynamic> toJson() => _$CheckOutReceiptDtoToJson(this);

  CheckOutReceipt toDomain() => CheckOutReceipt(
    id: id,
    plate: plate,
    entryTime: entryTime,
    exitTime: exitTime,
    amountCharged: amountCharged,
    ticketNumber: ticketNumber,
    paymentMethod: paymentMethod ?? 'cash',
    discountAmount: discountAmount,
    discountReason: discountReason,
    lostTicket: lostTicket,
  );
}
