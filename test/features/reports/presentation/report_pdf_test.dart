import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/l10n.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/presentation/report_pdf.dart';

final _revenue = RevenueReport(
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 1, 31),
  total: 150000,
  byDay: [DailyRevenue(date: DateTime(2026, 1, 1), amount: 100000)],
  byCategory: const [
    CategoryRevenue(categoryId: 1, categoryName: 'Car', amount: 100000),
  ],
  byPayment: const [
    PaymentRevenue(paymentMethod: 'cash', amount: 100000),
  ],
  byLot: const [
    LotRevenue(lotId: 1, lotName: 'Central', amount: 100000),
  ],
);

void main() {
  test('Success: the report PDF is a valid PDF document', () async {
    final bytes = await buildRevenueReportPdf(
      l10n: await AppLocalizations.delegate.load(defaultLocale),
      revenue: _revenue,
      headline: 'Reportes',
      lotName: 'Central',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('Security: an empty report still produces a readable PDF', () async {
    final bytes = await buildRevenueReportPdf(
      l10n: await AppLocalizations.delegate.load(defaultLocale),
      revenue: RevenueReport(
        startDate: DateTime(2026),
        endDate: DateTime(2026),
        total: 0,
        byDay: const [],
        byCategory: const [],
      ),
      headline: 'Reportes',
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
