import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/presentation/report_csv.dart';

RevenueReport _revenue({String category = 'Car'}) => RevenueReport(
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 1, 31),
  total: 150000,
  totalDiscounts: 5000,
  discountedSessions: 1,
  passRevenue: 80000,
  byDay: [DailyRevenue(date: DateTime(2026, 1, 2), amount: 100000)],
  byCategory: [
    CategoryRevenue(categoryId: 1, categoryName: category, amount: 100000),
  ],
  byPayment: const [PaymentRevenue(paymentMethod: 'cash', amount: 100000)],
  byLot: const [
    LotRevenue(lotId: 1, lotName: 'Central', amount: 150000),
  ],
);

void main() {
  test('Success: the CSV has headers and raw numbers per section', () {
    final csv = reportCsv(
      revenue: _revenue(),
      previousTotal: 100000,
      deltaPercent: 50,
    );
    final lines = csv.split('\n');

    expect(lines.first, 'section,label,value');
    expect(lines, contains('summary,total,150000'));
    expect(lines, contains('summary,discounts,5000'));
    expect(lines, contains('summary,pass_revenue,80000'));
    expect(lines, contains('by_day,2026-01-02,100000'));
    expect(lines, contains('by_category,Car,100000'));
    expect(lines, contains('by_payment,cash,100000'));
    expect(lines, contains('by_lot,Central,150000'));
    expect(lines, contains('comparison,variation_percent,50'));
    expect(lines, contains('comparison,previous_total,100000'));
  });

  test('Failure: without a previous window there is no comparison', () {
    final csv = reportCsv(revenue: _revenue());

    expect(csv, isNot(contains('comparison,')));
  });

  test('Security: commas and quotes in labels stay inside one cell', () {
    final csv = reportCsv(revenue: _revenue(category: 'Car, "big"'));

    expect(csv, contains('by_category,"Car, ""big""",100000'));
  });
}
