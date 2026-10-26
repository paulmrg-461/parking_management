import 'package:equatable/equatable.dart';

class CategoryOccupancySnapshot extends Equatable {
  const CategoryOccupancySnapshot({
    required this.categoryId,
    required this.name,
    required this.count,
    required this.capacity,
    required this.isFull,
  });

  final int categoryId;
  final String name;
  final int count;

  /// 0 = unlimited.
  final int capacity;
  final bool isFull;

  factory CategoryOccupancySnapshot.fromJson(Map<String, dynamic> json) =>
      CategoryOccupancySnapshot(
        categoryId: (json['category_id'] as num).toInt(),
        name: json['category_name'] as String,
        count: (json['count'] as num).toInt(),
        capacity: (json['capacity'] as num?)?.toInt() ?? 0,
        isFull: json['is_full'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [categoryId, name, count, capacity, isFull];
}

class OccupancySnapshot extends Equatable {
  const OccupancySnapshot({
    required this.totalOpen,
    required this.totalCapacity,
    this.byCategory = const [],
  });

  final int totalOpen;

  /// Sum of configured capacities (0 = unlimited).
  final int totalCapacity;
  final List<CategoryOccupancySnapshot> byCategory;

  bool get isFull => totalCapacity > 0 && totalOpen >= totalCapacity;

  factory OccupancySnapshot.fromJson(Map<String, dynamic> json) =>
      OccupancySnapshot(
        totalOpen: (json['total_open'] as num).toInt(),
        totalCapacity: (json['total_capacity'] as num?)?.toInt() ?? 0,
        byCategory: [
          for (final item
              in (json['by_category'] as List<dynamic>? ?? const []))
            CategoryOccupancySnapshot.fromJson(item as Map<String, dynamic>),
        ],
      );

  @override
  List<Object?> get props => [totalOpen, totalCapacity, byCategory];
}
