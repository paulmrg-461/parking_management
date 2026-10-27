// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revenue_report_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyRevenueDto _$DailyRevenueDtoFromJson(Map<String, dynamic> json) =>
    DailyRevenueDto(
      date: json['date'] as String,
      amount: (json['amount'] as num).toInt(),
    );

Map<String, dynamic> _$DailyRevenueDtoToJson(DailyRevenueDto instance) =>
    <String, dynamic>{'date': instance.date, 'amount': instance.amount};

CategoryRevenueDto _$CategoryRevenueDtoFromJson(Map<String, dynamic> json) =>
    CategoryRevenueDto(
      categoryId: (json['category_id'] as num).toInt(),
      categoryName: json['category_name'] as String,
      amount: (json['amount'] as num).toInt(),
    );

Map<String, dynamic> _$CategoryRevenueDtoToJson(CategoryRevenueDto instance) =>
    <String, dynamic>{
      'category_id': instance.categoryId,
      'category_name': instance.categoryName,
      'amount': instance.amount,
    };

PaymentRevenueDto _$PaymentRevenueDtoFromJson(Map<String, dynamic> json) =>
    PaymentRevenueDto(
      paymentMethod: json['payment_method'] as String,
      amount: (json['amount'] as num).toInt(),
    );

Map<String, dynamic> _$PaymentRevenueDtoToJson(PaymentRevenueDto instance) =>
    <String, dynamic>{
      'payment_method': instance.paymentMethod,
      'amount': instance.amount,
    };

LotRevenueDto _$LotRevenueDtoFromJson(Map<String, dynamic> json) =>
    LotRevenueDto(
      lotId: (json['lot_id'] as num).toInt(),
      lotName: json['lot'] as String,
      amount: (json['amount'] as num).toInt(),
      tickets: (json['tickets'] as num?)?.toInt() ?? 0,
      avgTicket: (json['avg_ticket'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$LotRevenueDtoToJson(LotRevenueDto instance) =>
    <String, dynamic>{
      'lot_id': instance.lotId,
      'lot': instance.lotName,
      'amount': instance.amount,
      'tickets': instance.tickets,
      'avg_ticket': instance.avgTicket,
    };

DiscountAuditDto _$DiscountAuditDtoFromJson(Map<String, dynamic> json) =>
    DiscountAuditDto(
      sessionId: (json['session_id'] as num).toInt(),
      plate: json['plate'] as String,
      amountCharged: (json['amount_charged'] as num).toInt(),
      discountAmount: (json['discount_amount'] as num).toInt(),
      discountAt: DateTime.parse(json['discount_at'] as String),
      admin: json['admin'] as String,
      ticketNumber: json['ticket_number'] as String?,
      reason: json['discount_reason'] as String?,
    );

Map<String, dynamic> _$DiscountAuditDtoToJson(DiscountAuditDto instance) =>
    <String, dynamic>{
      'session_id': instance.sessionId,
      'plate': instance.plate,
      'amount_charged': instance.amountCharged,
      'discount_amount': instance.discountAmount,
      'discount_at': instance.discountAt.toIso8601String(),
      'admin': instance.admin,
      'ticket_number': instance.ticketNumber,
      'discount_reason': instance.reason,
    };

RevenueReportDto _$RevenueReportDtoFromJson(
  Map<String, dynamic> json,
) => RevenueReportDto(
  startDate: json['start_date'] as String,
  endDate: json['end_date'] as String,
  total: (json['total'] as num).toInt(),
  byDay: (json['by_day'] as List<dynamic>)
      .map((e) => DailyRevenueDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  byCategory: (json['by_category'] as List<dynamic>)
      .map((e) => CategoryRevenueDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  byPayment:
      (json['by_payment'] as List<dynamic>?)
          ?.map((e) => PaymentRevenueDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  totalDiscounts: (json['total_discounts'] as num?)?.toInt() ?? 0,
  discountedSessions: (json['discounted_sessions'] as num?)?.toInt() ?? 0,
  discountAudit:
      (json['discount_audit'] as List<dynamic>?)
          ?.map((e) => DiscountAuditDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  passRevenue: (json['pass_revenue'] as num?)?.toInt() ?? 0,
  passByPayment:
      (json['pass_by_payment'] as List<dynamic>?)
          ?.map((e) => PaymentRevenueDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  byLot:
      (json['by_lot'] as List<dynamic>?)
          ?.map((e) => LotRevenueDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$RevenueReportDtoToJson(RevenueReportDto instance) =>
    <String, dynamic>{
      'start_date': instance.startDate,
      'end_date': instance.endDate,
      'total': instance.total,
      'by_day': instance.byDay,
      'by_category': instance.byCategory,
      'by_payment': instance.byPayment,
      'total_discounts': instance.totalDiscounts,
      'discounted_sessions': instance.discountedSessions,
      'discount_audit': instance.discountAudit,
      'pass_revenue': instance.passRevenue,
      'pass_by_payment': instance.passByPayment,
      'by_lot': instance.byLot,
    };
