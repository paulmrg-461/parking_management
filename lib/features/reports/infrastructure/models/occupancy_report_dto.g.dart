// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'occupancy_report_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CategoryOccupancyDto _$CategoryOccupancyDtoFromJson(
  Map<String, dynamic> json,
) => CategoryOccupancyDto(
  categoryId: (json['category_id'] as num).toInt(),
  categoryName: json['category_name'] as String,
  count: (json['count'] as num).toInt(),
  capacity: (json['capacity'] as num?)?.toInt() ?? 0,
  isFull: json['isFull'] as bool? ?? false,
);

Map<String, dynamic> _$CategoryOccupancyDtoToJson(
  CategoryOccupancyDto instance,
) => <String, dynamic>{
  'category_id': instance.categoryId,
  'category_name': instance.categoryName,
  'count': instance.count,
  'capacity': instance.capacity,
  'isFull': instance.isFull,
};

OccupancyReportDto _$OccupancyReportDtoFromJson(Map<String, dynamic> json) =>
    OccupancyReportDto(
      totalOpen: (json['total_open'] as num).toInt(),
      byCategory: (json['by_category'] as List<dynamic>)
          .map((e) => CategoryOccupancyDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCapacity: (json['total_capacity'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$OccupancyReportDtoToJson(OccupancyReportDto instance) =>
    <String, dynamic>{
      'total_open': instance.totalOpen,
      'by_category': instance.byCategory,
      'total_capacity': instance.totalCapacity,
    };
