import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/occupancy_report.dart';

part 'occupancy_report_dto.g.dart';

@JsonSerializable()
class CategoryOccupancyDto {
  const CategoryOccupancyDto({
    required this.categoryId,
    required this.categoryName,
    required this.count,
  });

  factory CategoryOccupancyDto.fromJson(Map<String, dynamic> json) =>
      _$CategoryOccupancyDtoFromJson(json);

  @JsonKey(name: 'category_id')
  final int categoryId;

  @JsonKey(name: 'category_name')
  final String categoryName;

  final int count;

  Map<String, dynamic> toJson() => _$CategoryOccupancyDtoToJson(this);

  CategoryOccupancy toDomain() => CategoryOccupancy(
    categoryId: categoryId,
    categoryName: categoryName,
    count: count,
  );
}

@JsonSerializable()
class OccupancyReportDto {
  const OccupancyReportDto({required this.totalOpen, required this.byCategory});

  factory OccupancyReportDto.fromJson(Map<String, dynamic> json) =>
      _$OccupancyReportDtoFromJson(json);

  @JsonKey(name: 'total_open')
  final int totalOpen;

  @JsonKey(name: 'by_category')
  final List<CategoryOccupancyDto> byCategory;

  Map<String, dynamic> toJson() => _$OccupancyReportDtoToJson(this);

  OccupancyReport toDomain() => OccupancyReport(
    totalOpen: totalOpen,
    byCategory: byCategory.map((dto) => dto.toDomain()).toList(),
  );
}
