import 'package:equatable/equatable.dart';

/// One operator shift with its cash reconciliation totals.
class ShiftSummary extends Equatable {
  const ShiftSummary({
    required this.id,
    required this.operatorId,
    required this.openedAt,
    required this.openingFloat,
    required this.expectedCash,
    this.closedAt,
    this.countedCash,
    this.difference,
    this.notes,
    this.sessionCount = 0,
    this.revenue = 0,
    this.cashSales = 0,
    this.cardSales = 0,
    this.transferSales = 0,
    this.passSales = 0,
    this.exemptSales = 0,
    this.discounts = 0,
    this.withdrawals = 0,
    this.deposits = 0,
  });

  final int id;
  final int operatorId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int openingFloat;
  final int? countedCash;
  final int expectedCash;
  final int? difference;
  final String? notes;
  final int sessionCount;
  final int revenue;
  final int cashSales;
  final int cardSales;
  final int transferSales;
  final int passSales;
  final int exemptSales;
  final int discounts;
  final int withdrawals;
  final int deposits;

  bool get isOpen => closedAt == null;

  factory ShiftSummary.fromJson(Map<String, dynamic> json) => ShiftSummary(
    id: (json['id'] as num).toInt(),
    operatorId: (json['operator_id'] as num).toInt(),
    openedAt: DateTime.parse(json['opened_at'] as String),
    closedAt: json['closed_at'] == null
        ? null
        : DateTime.parse(json['closed_at'] as String),
    openingFloat: (json['opening_float'] as num?)?.toInt() ?? 0,
    countedCash: (json['counted_cash'] as num?)?.toInt(),
    expectedCash: (json['expected_cash'] as num?)?.toInt() ?? 0,
    difference: (json['difference'] as num?)?.toInt(),
    notes: json['notes'] as String?,
    sessionCount: (json['session_count'] as num?)?.toInt() ?? 0,
    revenue: (json['revenue'] as num?)?.toInt() ?? 0,
    cashSales: (json['cash_sales'] as num?)?.toInt() ?? 0,
    cardSales: (json['card_sales'] as num?)?.toInt() ?? 0,
    transferSales: (json['transfer_sales'] as num?)?.toInt() ?? 0,
    passSales: (json['pass_sales'] as num?)?.toInt() ?? 0,
    exemptSales: (json['exempt_sales'] as num?)?.toInt() ?? 0,
    discounts: (json['discounts'] as num?)?.toInt() ?? 0,
    withdrawals: (json['withdrawals'] as num?)?.toInt() ?? 0,
    deposits: (json['deposits'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [
    id,
    operatorId,
    openedAt,
    closedAt,
    openingFloat,
    countedCash,
    expectedCash,
    difference,
    notes,
    sessionCount,
    revenue,
    cashSales,
    cardSales,
    transferSales,
    passSales,
    exemptSales,
    discounts,
    withdrawals,
    deposits,
  ];
}
