import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/revenue_report.dart';

part 'revenue_report_dto.g.dart';

@JsonSerializable()
class DailyRevenueDto {
  const DailyRevenueDto({required this.date, required this.amount});

  factory DailyRevenueDto.fromJson(Map<String, dynamic> json) =>
      _$DailyRevenueDtoFromJson(json);

  final String date;
  final int amount;

  Map<String, dynamic> toJson() => _$DailyRevenueDtoToJson(this);

  DailyRevenue toDomain() =>
      DailyRevenue(date: DateTime.parse(date), amount: amount);
}

@JsonSerializable()
class CategoryRevenueDto {
  const CategoryRevenueDto({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  factory CategoryRevenueDto.fromJson(Map<String, dynamic> json) =>
      _$CategoryRevenueDtoFromJson(json);

  @JsonKey(name: 'category_id')
  final int categoryId;

  @JsonKey(name: 'category_name')
  final String categoryName;

  final int amount;

  Map<String, dynamic> toJson() => _$CategoryRevenueDtoToJson(this);

  CategoryRevenue toDomain() => CategoryRevenue(
    categoryId: categoryId,
    categoryName: categoryName,
    amount: amount,
  );
}

@JsonSerializable()
class RevenueReportDto {
  const RevenueReportDto({
    required this.startDate,
    required this.endDate,
    required this.total,
    required this.byDay,
    required this.byCategory,
  });

  factory RevenueReportDto.fromJson(Map<String, dynamic> json) =>
      _$RevenueReportDtoFromJson(json);

  @JsonKey(name: 'start_date')
  final String startDate;

  @JsonKey(name: 'end_date')
  final String endDate;

  final int total;

  @JsonKey(name: 'by_day')
  final List<DailyRevenueDto> byDay;

  @JsonKey(name: 'by_category')
  final List<CategoryRevenueDto> byCategory;

  Map<String, dynamic> toJson() => _$RevenueReportDtoToJson(this);

  RevenueReport toDomain() => RevenueReport(
    startDate: DateTime.parse(startDate),
    endDate: DateTime.parse(endDate),
    total: total,
    byDay: byDay.map((dto) => dto.toDomain()).toList(),
    byCategory: byCategory.map((dto) => dto.toDomain()).toList(),
  );
}
