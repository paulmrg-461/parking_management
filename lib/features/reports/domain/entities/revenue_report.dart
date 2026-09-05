import 'package:equatable/equatable.dart';

/// Revenue collected on a single calendar day, part of [RevenueReport.byDay].
class DailyRevenue extends Equatable {
  const DailyRevenue({required this.date, required this.amount});

  final DateTime date;
  final int amount;

  @override
  List<Object?> get props => [date, amount];
}

/// Revenue collected by a vehicle category, part of [RevenueReport.byCategory].
class CategoryRevenue extends Equatable {
  const CategoryRevenue({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  final int categoryId;
  final String categoryName;
  final int amount;

  @override
  List<Object?> get props => [categoryId, categoryName, amount];
}

/// Revenue report for a date range, as returned by
/// `GET /api/reports/revenue`.
class RevenueReport extends Equatable {
  const RevenueReport({
    required this.startDate,
    required this.endDate,
    required this.total,
    required this.byDay,
    required this.byCategory,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int total;
  final List<DailyRevenue> byDay;
  final List<CategoryRevenue> byCategory;

  @override
  List<Object?> get props => [startDate, endDate, total, byDay, byCategory];
}
