import 'package:equatable/equatable.dart';

import 'merchant.dart';

/// One row of the settlement report (the totals row has a null merchantId).
class MerchantSettlementRow extends Equatable {
  const MerchantSettlementRow({
    this.merchantId,
    required this.name,
    this.billingMode,
    this.validations = 0,
    this.applied = 0,
    this.forfeited = 0,
    this.revoked = 0,
    this.pendingNow = 0,
    this.discountedAmount = 0,
    this.amountOwed = 0,
    this.courtesyAmount = 0,
  });

  final int? merchantId;
  final String name;
  final MerchantBillingMode? billingMode;
  final int validations;
  final int applied;
  final int forfeited;
  final int revoked;
  final int pendingNow;
  final int discountedAmount;
  final int amountOwed;
  final int courtesyAmount;

  factory MerchantSettlementRow.fromJson(Map<String, dynamic> json) =>
      MerchantSettlementRow(
        merchantId: (json['merchant_id'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
        billingMode: json['billing_mode'] == null
            ? null
            : MerchantBillingModeX.parse(json['billing_mode'] as String?),
        validations: (json['validations'] as num?)?.toInt() ?? 0,
        applied: (json['applied'] as num?)?.toInt() ?? 0,
        forfeited: (json['forfeited'] as num?)?.toInt() ?? 0,
        revoked: (json['revoked'] as num?)?.toInt() ?? 0,
        pendingNow: (json['pending_now'] as num?)?.toInt() ?? 0,
        discountedAmount: (json['discounted_amount'] as num?)?.toInt() ?? 0,
        amountOwed: (json['amount_owed'] as num?)?.toInt() ?? 0,
        courtesyAmount: (json['courtesy_amount'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [
    merchantId,
    name,
    billingMode,
    validations,
    applied,
    forfeited,
    revoked,
    pendingNow,
    discountedAmount,
    amountOwed,
    courtesyAmount,
  ];
}

class MerchantSettlement extends Equatable {
  const MerchantSettlement({
    required this.from,
    required this.to,
    this.rows = const [],
    this.totals = const MerchantSettlementRow(name: ''),
  });

  final DateTime from;
  final DateTime to;
  final List<MerchantSettlementRow> rows;
  final MerchantSettlementRow totals;

  static final empty = MerchantSettlement(
    from: DateTime(1970),
    to: DateTime(1970),
  );

  bool get hasActivity =>
      totals.validations > 0 || rows.any((row) => row.validations > 0);

  factory MerchantSettlement.fromJson(Map<String, dynamic> json) =>
      MerchantSettlement(
        from: DateTime.tryParse(json['from'] as String? ?? '') ??
            DateTime.now(),
        to: DateTime.tryParse(json['to'] as String? ?? '') ?? DateTime.now(),
        rows: [
          for (final item in (json['merchants'] as List? ?? const []))
            if (item is Map)
              MerchantSettlementRow.fromJson(
                Map<String, dynamic>.from(item),
              ),
        ],
        totals: json['totals'] is Map
            ? MerchantSettlementRow.fromJson(
                Map<String, dynamic>.from(json['totals'] as Map),
              )
            : const MerchantSettlementRow(name: ''),
      );

  @override
  List<Object?> get props => [from, to, rows, totals];
}
