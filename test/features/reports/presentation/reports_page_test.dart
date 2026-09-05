import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reports/application/reports_cubit.dart';
import 'package:parking_management/features/reports/domain/entities/occupancy_report.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/domain/repositories/report_repository.dart';
import 'package:parking_management/features/reports/presentation/reports_page.dart';

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository(this.revenue, this.occupancy);

  final RevenueReport revenue;
  final OccupancyReport occupancy;

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async => revenue;

  @override
  Future<OccupancyReport> getOccupancyReport() async => occupancy;
}

void main() {
  testWidgets(
    'Success: renders total revenue and occupancy total once loaded',
    (tester) async {
      final revenue = RevenueReport(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        total: 150000,
        byDay: [DailyRevenue(date: DateTime(2026, 1, 1), amount: 100000)],
        byCategory: const [
          CategoryRevenue(categoryId: 1, categoryName: 'Car', amount: 100000),
        ],
      );
      const occupancy = OccupancyReport(
        totalOpen: 7,
        byCategory: [
          CategoryOccupancy(categoryId: 1, categoryName: 'Car', count: 7),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ReportsCubit>(
            create: (_) =>
                ReportsCubit(_FakeReportRepository(revenue, occupancy)),
            child: const ReportsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$150.000'), findsOneWidget);
      expect(find.text('Open sessions: 7'), findsOneWidget);
      expect(find.text('Revenue by category'), findsOneWidget);
    },
  );
}
