import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/theme/contrast.dart';
import 'package:parking_management/features/reports/application/reports_cubit.dart';
import 'package:parking_management/features/reports/domain/entities/occupancy_report.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/domain/entities/whatsapp_report.dart';
import 'package:parking_management/features/reports/domain/repositories/report_repository.dart';
import 'package:parking_management/features/reports/presentation/report_colors.dart';
import 'package:parking_management/features/reports/presentation/reports_page.dart';

import '../../../helpers/test_app.dart';

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository(this.revenue, this.occupancy);

  final RevenueReport revenue;
  final OccupancyReport occupancy;
  Failure? error;
  bool? lastAllLots;
  WhatsappReport whatsapp = WhatsappReport(
    sent: 8,
    failed: 1,
    pending: 2,
    byDay: [WhatsappDaily(date: DateTime(2026, 1, 1), sent: 8, failed: 1)],
  );

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    bool allLots = false,
  }) async {
    lastAllLots = allLots;
    return error == null ? revenue : throw error!;
  }

  @override
  Future<WhatsappReport> getWhatsappReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async => whatsapp;

  @override
  Future<OccupancyReport> getOccupancyReport() async => occupancy;
}

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
    LotRevenue(lotId: 1, lotName: 'Central', amount: 120000, tickets: 4, avgTicket: 30000),
    LotRevenue(lotId: 2, lotName: 'North', amount: 30000, tickets: 2, avgTicket: 15000),
  ],
);

const _occupancy = OccupancyReport(
  totalOpen: 7,
  byCategory: [CategoryOccupancy(categoryId: 1, categoryName: 'Car', count: 7)],
);

Future<_FakeReportRepository> _pump(
  WidgetTester tester, {
  Failure? error,
}) async {
  final repository = _FakeReportRepository(_revenue, _occupancy)
    ..error = error;
  await tester.pumpWidget(
    testApp(
      BlocProvider<ReportsCubit>(
        create: (_) => ReportsCubit(repository),
        child: const ReportsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('Success: renders total revenue and occupancy in Spanish', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('\$150.000'), findsOneWidget);
    expect(find.text('Ingresos por categoría'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Efectivo'), 200);
    expect(find.text('Ingresos por método de pago'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Vehículos dentro: 7'), 200);
    expect(find.text('Vehículos dentro: 7'), findsOneWidget);
  });

  testWidgets('Failure: an error offers retry that reloads', (tester) async {
    final repository = await _pump(tester, error: const ServerFailure());

    expect(find.text('Reintentar'), findsOneWidget);
    repository.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('\$150.000'), findsOneWidget);
  });

  testWidgets('A11y: chart labels scale with text size and meet contrast', (
    tester,
  ) async {
    await _pump(tester);

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  test('A11y: muted/secondary chart text ≥ 4.5:1 on the chart surface', () {
    for (final brightness in Brightness.values) {
      final surface = ReportColors.chartSurfaceFor(brightness);
      expect(
        contrastRatio(ReportColors.mutedTextFor(brightness), surface),
        greaterThanOrEqualTo(wcagAaNormalText),
      );
      expect(
        contrastRatio(ReportColors.secondaryTextFor(brightness), surface),
        greaterThanOrEqualTo(wcagAaNormalText),
      );
    }
  });

  testWidgets('Success: the consolidated switch asks for every lot', (
    tester,
  ) async {
    final repository = await _pump(tester);

    expect(find.text('Ingresos por sede'), findsNothing);

    await tester.tap(find.text('Todas las sedes'));
    await tester.pumpAndSettle();

    expect(repository.lastAllLots, isTrue);
    expect(find.text('Ingresos por sede'), findsOneWidget);
    expect(find.text('Central'), findsOneWidget);
    expect(find.text('80% del total'), findsOneWidget);
  });

  testWidgets('Success: WhatsApp delivery metrics are shown', (tester) async {
    await _pump(tester);

    await tester.scrollUntilVisible(find.text('WhatsApp'), 300);
    expect(find.text('Enviados'), findsOneWidget);
    expect(find.text('Fallidos'), findsOneWidget);
    expect(find.text('En cola'), findsOneWidget);

    await tester.scrollUntilVisible(find.textContaining('8 enviados'), 300);
    expect(find.textContaining('8 enviados'), findsOneWidget);
  });
}
