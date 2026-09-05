import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/cop_formatter.dart';
import '../application/reports_cubit.dart';
import 'widgets/category_bar_list.dart';
import 'widgets/revenue_by_day_chart.dart';

/// Admin reports screen: a date-range picker driving a revenue report
/// (total, by-day chart, by-category breakdown) and a current occupancy
/// snapshot (total open, by-category breakdown).
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
    _load();
  }

  void _load() {
    context.read<ReportsCubit>().loadReports(
          startDate: _range.start,
          endDate: _range.end,
        );
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Change date range',
            onPressed: () => _pickRange(context),
          ),
        ],
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) => switch (state) {
          ReportsInitial() ||
          ReportsLoading() =>
            const Center(child: CircularProgressIndicator()),
          ReportsFailure(message: final message) =>
            Center(child: Text(message)),
          ReportsLoaded(revenue: final revenue, occupancy: final occupancy) =>
            RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${_shortDate(_range.start)} - ${_shortDate(_range.end)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total revenue',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    CopFormatter.format(revenue.total),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Revenue by day',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  RevenueByDayChart(byDay: revenue.byDay),
                  const SizedBox(height: 24),
                  Text(
                    'Revenue by category',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  CategoryBarList(
                    items: [
                      for (final category in revenue.byCategory)
                        CategoryBarItem(
                          label: category.categoryName,
                          value: category.amount,
                        ),
                    ],
                    formatValue: CopFormatter.format,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Occupancy',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open sessions: ${occupancy.totalOpen}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  CategoryBarList(
                    items: [
                      for (final category in occupancy.byCategory)
                        CategoryBarItem(
                          label: category.categoryName,
                          value: category.count,
                        ),
                    ],
                    formatValue: (value) => value.toString(),
                  ),
                ],
              ),
            ),
        },
      ),
    );
  }

  static String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
