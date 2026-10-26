import 'package:equatable/equatable.dart';

/// Currently-open session count for a vehicle category, part of
/// [OccupancyReport.byCategory].
class CategoryOccupancy extends Equatable {
  const CategoryOccupancy({
    required this.categoryId,
    required this.categoryName,
    required this.count,
    this.capacity = 0,
    this.isFull = false,
  });

  final int categoryId;
  final String categoryName;
  final int count;
  final int capacity;
  final bool isFull;

  @override
  List<Object?> get props => [categoryId, categoryName, count, capacity, isFull];
}

/// Current occupancy snapshot, as returned by `rpc/report_occupancy`.
class OccupancyReport extends Equatable {
  const OccupancyReport({
    required this.totalOpen,
    required this.byCategory,
    this.totalCapacity = 0,
  });

  final int totalOpen;
  final List<CategoryOccupancy> byCategory;
  final int totalCapacity;

  @override
  List<Object?> get props => [totalOpen, byCategory, totalCapacity];
}
