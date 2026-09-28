import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/theme/contrast.dart';
import 'package:parking_management/features/reports/application/reports_cubit.dart';
import 'package:parking_management/features/reports/domain/entities/occupancy_report.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/domain/repositories/report_repository.dart';
import 'package:parking_management/features/reports/presentation/report_colors.dart';
import 'package:parking_management/features/reports/presentation/reports_page.dart';

import '../../../helpers/test_app.dart';

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository(this.revenue, this.occupancy);

  final RevenueReport revenue;
  final OccupancyReport occupancy;
  Failure? error;

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async => error == null ? revenue : throw error!;

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
    expect(find.text('Vehículos dentro: 7'), findsOneWidget);
    expect(find.text('Ingresos por categoría'), findsOneWidget);
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
}
