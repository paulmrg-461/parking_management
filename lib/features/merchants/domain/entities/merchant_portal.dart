import 'package:equatable/equatable.dart';

import 'merchant.dart';

/// Public identity of a merchant, resolved from the link token.
class MerchantPortal extends Equatable {
  const MerchantPortal({
    required this.merchantName,
    required this.kind,
    required this.value,
    required this.lotName,
    this.maxAmount,
    this.lockedUntil,
  });

  final String merchantName;
  final MerchantBenefitKind kind;
  final int value;
  final int? maxAmount;
  final String lotName;
  final DateTime? lockedUntil;

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  factory MerchantPortal.fromJson(Map<String, dynamic> json) => MerchantPortal(
    merchantName: json['merchant_name'] as String? ?? '',
    kind: MerchantBenefitKindX.parse(json['benefit_kind'] as String?),
    value: (json['benefit_value'] as num?)?.toInt() ?? 0,
    maxAmount: (json['max_amount'] as num?)?.toInt(),
    lotName: json['lot_name'] as String? ?? '',
    lockedUntil: DateTime.tryParse(json['locked_until'] as String? ?? ''),
  );

  @override
  List<Object?> get props => [
    merchantName,
    kind,
    value,
    maxAmount,
    lotName,
    lockedUntil,
  ];
}
