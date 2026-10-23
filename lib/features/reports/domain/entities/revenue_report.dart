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

/// Revenue collected through one payment method.
class PaymentRevenue extends Equatable {
  const PaymentRevenue({required this.paymentMethod, required this.amount});

  final String paymentMethod;
  final int amount;

  @override
  List<Object?> get props => [paymentMethod, amount];
}

/// Revenue report for a date range, as returned by
/// `rpc/report_revenue`.
class RevenueReport extends Equatable {
  const RevenueReport({
    required this.startDate,
    required this.endDate,
    required this.total,
    required this.byDay,
    required this.byCategory,
    this.byPayment = const [],
  });

  final DateTime startDate;
  final DateTime endDate;
  final int total;
  final List<DailyRevenue> byDay;
  final List<CategoryRevenue> byCategory;
  final List<PaymentRevenue> byPayment;

  @override
  List<Object?> get props =>
      [startDate, endDate, total, byDay, byCategory, byPayment];
}
