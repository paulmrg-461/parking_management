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

RevenueReportDto _$RevenueReportDtoFromJson(Map<String, dynamic> json) =>
    RevenueReportDto(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      total: (json['total'] as num).toInt(),
      byDay: (json['by_day'] as List<dynamic>)
          .map((e) => DailyRevenueDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      byCategory: (json['by_category'] as List<dynamic>)
          .map((e) => CategoryRevenueDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RevenueReportDtoToJson(RevenueReportDto instance) =>
    <String, dynamic>{
      'start_date': instance.startDate,
      'end_date': instance.endDate,
      'total': instance.total,
      'by_day': instance.byDay,
      'by_category': instance.byCategory,
    };
