import 'package:equatable/equatable.dart';

/// Currently-open session count for a vehicle category, part of
/// [OccupancyReport.byCategory].
class CategoryOccupancy extends Equatable {
  const CategoryOccupancy({
    required this.categoryId,
    required this.categoryName,
    required this.count,
  });

  final int categoryId;
  final String categoryName;
  final int count;

  @override
  List<Object?> get props => [categoryId, categoryName, count];
}

/// Current occupancy snapshot, as returned by `GET /api/reports/occupancy`.
class OccupancyReport extends Equatable {
  const OccupancyReport({required this.totalOpen, required this.byCategory});

  final int totalOpen;
  final List<CategoryOccupancy> byCategory;

  @override
  List<Object?> get props => [totalOpen, byCategory];
}
