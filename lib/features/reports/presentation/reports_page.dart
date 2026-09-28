import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/sync_badge.dart';
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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTitle),
        actions: [
          AppIconButton(
            icon: Icons.date_range,
            tooltip: l10n.reportsRangeTooltip,
            onPressed: () => _pickRange(context),
          ),
          const SyncBadge(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: BlocBuilder<ReportsCubit, ReportsState>(
          builder: (context, state) => AsyncView<ReportsLoaded>(
            status: _status(context, state),
            builder: (loaded) => _ReportsBody(range: _range, loaded: loaded),
          ),
        ),
      ),
    );
  }

  AsyncStatus<ReportsLoaded> _status(
    BuildContext context,
    ReportsState state,
  ) => switch (state) {
    ReportsInitial() || ReportsLoading() => const AsyncLoading(),
    ReportsFailure(:final message, :final failure) => AsyncFailed(
      context.l10n.errorText(message, failure),
      _load,
    ),
    final ReportsLoaded loaded => AsyncReady(loaded),
  };
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.range, required this.loaded});

  final DateTimeRange range;
  final ReportsLoaded loaded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final revenue = loaded.revenue;
    final occupancy = loaded.occupancy;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        Text(
          l10n.monthlyPassPeriod(
            Formatters.date(range.start),
            Formatters.date(range.end),
          ),
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: Space.sm),
        Text(l10n.reportsTotalRevenue, style: textTheme.labelLarge),
        MoneyText(revenue.total, style: textTheme.headlineMedium),
        const SizedBox(height: Space.lg),
        _SectionTitle(l10n.reportsRevenueByDay),
        RevenueByDayChart(byDay: revenue.byDay),
        const SizedBox(height: Space.lg),
        _SectionTitle(l10n.reportsRevenueByCategory),
        CategoryBarList(
          items: [
            for (final category in revenue.byCategory)
              CategoryBarItem(
                label: category.categoryName,
                value: category.amount,
              ),
          ],
          formatValue: Formatters.money,
        ),
        const SizedBox(height: Space.lg),
        _SectionTitle(l10n.reportsOccupancy),
        Text(
          l10n.reportsOpenSessions(occupancy.totalOpen),
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: Space.sm),
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}
