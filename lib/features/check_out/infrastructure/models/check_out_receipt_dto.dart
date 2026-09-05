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

  Map<String, dynamic> toJson() => _$CheckOutReceiptDtoToJson(this);

  CheckOutReceipt toDomain() => CheckOutReceipt(
        id: id,
        plate: plate,
        entryTime: entryTime,
        exitTime: exitTime,
        amountCharged: amountCharged,
        ticketNumber: ticketNumber,
      );
}
