import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/receipt/payment_method.dart';
import '../../../core/receipt/pdf_share.dart';
import '../../../core/utils/formatters.dart';
import '../../lots/application/lots_cubit.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/sync_badge.dart';
import '../application/reports_cubit.dart';
import 'report_csv.dart';
import 'report_pdf.dart';
import 'widgets/category_bar_list.dart';
import 'widgets/lot_comparison.dart';
import 'widgets/revenue_by_day_chart.dart';

/// Admin reports screen: a date-range picker driving a revenue report
/// (total, by-day chart, by-category breakdown) and a current occupancy
/// snapshot (total open, by-category breakdown).
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

enum _RangePreset { today, last7, last30 }

class _ReportsPageState extends State<ReportsPage> {
  late DateTimeRange _range;
  _RangePreset? _preset = _RangePreset.last30;
  bool _allLots = false;
  bool _exporting = false;

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

  void _selectPreset(_RangePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = switch (preset) {
      _RangePreset.today => 0,
      _RangePreset.last7 => 6,
      _RangePreset.last30 => 29,
    };
    setState(() {
      _preset = preset;
      _range = DateTimeRange(
        start: today.subtract(Duration(days: days)),
        end: today,
      );
    });
    _load();
  }

  void _load() {
    context.read<ReportsCubit>().loadReports(
      startDate: _range.start,
      endDate: _range.end,
      allLots: _allLots,
    );
  }

  String? _lotName(BuildContext context, bool allLots) {
    if (allLots) {
      return context.l10n.reportsAllLots;
    }
    try {
      final state = context.read<LotsCubit>().state;
      if (state is LotsLoaded) {
        return state.active?.name;
      }
    } on ProviderNotFoundException {
      // Isolated tests do not provide the lot cubit.
    }
    return null;
  }

  Future<void> _export(BuildContext context) async {
    final state = context.read<ReportsCubit>().state;
    if (state is! ReportsLoaded || _exporting) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final bytes = await buildRevenueReportPdf(
        l10n: context.l10n,
        revenue: state.revenue,
        headline: context.l10n.reportsTitle,
        lotName: _lotName(context, state.allLots),
        previousTotal: state.previousTotal,
        deltaPercent: state.deltaPercent,
      );
      if (!context.mounted) {
        return;
      }
      await sharePdfBytes(
        context,
        bytes: bytes,
        filename: pdfFileName('reporte', _range.start, _range.end),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _copyCsv(BuildContext context) async {
    final state = context.read<ReportsCubit>().state;
    if (state is! ReportsLoaded) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: reportCsv(
          revenue: state.revenue,
          previousTotal: state.previousTotal,
          deltaPercent: state.deltaPercent,
        ),
      ),
    );
    if (context.mounted) {
      showInfoSnack(context, context.l10n.reportsCsvCopied);
    }
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
      setState(() {
        _range = picked;
        _preset = null;
      });
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
            icon: Icons.ios_share,
            tooltip: l10n.actionExportPdf,
            onPressed: () => _export(context),
          ),
          AppIconButton(
            icon: Icons.table_view_outlined,
            tooltip: l10n.reportsExportCsv,
            onPressed: () => _copyCsv(context),
          ),
          AppIconButton(
            icon: Icons.date_range,
            tooltip: l10n.reportsRangeTooltip,
            onPressed: () => _pickRange(context),
          ),
          const SyncBadge(),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
            child: SegmentedButton<_RangePreset>(
              segments: [
                ButtonSegment(
                  value: _RangePreset.today,
                  label: Text(l10n.reportsToday),
                ),
                ButtonSegment(
                  value: _RangePreset.last7,
                  label: Text(l10n.reportsLast7),
                ),
                ButtonSegment(
                  value: _RangePreset.last30,
                  label: Text(l10n.reportsLast30),
                ),
              ],
              selected: {?_preset},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  _selectPreset(selection.first);
                }
              },
            ),
          ),
          SwitchListTile(
            value: _allLots,
            onChanged: (value) {
              setState(() => _allLots = value);
              _load();
            },
            title: Text(l10n.reportsAllLots),
            subtitle: Text(l10n.reportsAllLotsHint),
            secondary: const Icon(Icons.location_city_outlined),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _load(),
              child: BlocBuilder<ReportsCubit, ReportsState>(
                builder: (context, state) => AsyncView<ReportsLoaded>(
                  status: _status(context, state),
                  builder: (loaded) =>
                      _ReportsBody(range: _range, loaded: loaded),
                ),
              ),
            ),
          ),
        ],
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
        if (loaded.deltaPercent case final delta?) ...[
          const SizedBox(height: Space.xs),
          _DeltaRow(delta: delta, previous: loaded.previousTotal!),
        ],
        if (loaded.allLots && revenue.byLot.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          _SectionTitle(l10n.reportsByLot),
          LotComparison(lots: revenue.byLot),
        ],
        if (revenue.totalDiscounts > 0) ...[
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Text(l10n.reportsTotalDiscounts, style: textTheme.bodyMedium),
              const SizedBox(width: Space.xs),
              MoneyText(revenue.totalDiscounts, style: textTheme.titleSmall),
              const SizedBox(width: Space.sm),
              Text(
                l10n.reportsDiscountedSessions(revenue.discountedSessions),
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ],
        if (revenue.discountAudit.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          _SectionTitle(l10n.reportsDiscountLog),
          for (final discount in revenue.discountAudit)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${discount.plate} · ${Formatters.dateTime(discount.discountAt)}',
              ),
              subtitle: Text(
                [
                  if (discount.reason != null) discount.reason!,
                  l10n.reportsDiscountBy(discount.admin),
                  if (discount.ticketNumber != null) discount.ticketNumber!,
                ].join(' · '),
              ),
              trailing: Text(
                '-${Formatters.money(discount.discountAmount)}',
                style: textTheme.titleSmall,
              ),
            ),
        ],
        if (revenue.passRevenue > 0) ...[
          const SizedBox(height: Space.lg),
          _SectionTitle(l10n.reportsPassRevenue),
          MoneyText(revenue.passRevenue, style: textTheme.headlineSmall),
          if (revenue.passByPayment.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            CategoryBarList(
              items: [
                for (final payment in revenue.passByPayment)
                  CategoryBarItem(
                    label: paymentMethodLabel(l10n, payment.paymentMethod),
                    value: payment.amount,
                  ),
              ],
              formatValue: Formatters.money,
            ),
          ],
        ],
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
        if (revenue.byPayment.isNotEmpty) ...[
          _SectionTitle(l10n.reportsRevenueByPayment),
          CategoryBarList(
            items: [
              for (final payment in revenue.byPayment)
                CategoryBarItem(
                  label: paymentMethodLabel(l10n, payment.paymentMethod),
                  value: payment.amount,
                ),
            ],
            formatValue: Formatters.money,
          ),
          const SizedBox(height: Space.lg),
        ],
        if (loaded.whatsapp.hasData) ...[
          _SectionTitle(l10n.reportsWhatsapp),
          Row(
            children: [
              Expanded(
                child: _WhatsappMetric(
                  label: l10n.reportsWhatsappSent,
                  value: '${loaded.whatsapp.sent}',
                ),
              ),
              Expanded(
                child: _WhatsappMetric(
                  label: l10n.reportsWhatsappFailed,
                  value: '${loaded.whatsapp.failed}',
                  warning: loaded.whatsapp.failed > 0,
                ),
              ),
              Expanded(
                child: _WhatsappMetric(
                  label: l10n.reportsWhatsappPending,
                  value: '${loaded.whatsapp.pending}',
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          for (final day in loaded.whatsapp.byDay)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(Formatters.date(day.date))),
                  Text(
                    l10n.reportsWhatsappDay(day.sent, day.failed),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.lg),
        ],
        _SectionTitle(l10n.reportsOccupancy),
        Text(
          occupancy.totalCapacity > 0
              ? l10n.reportsOccupancyOf(
                  occupancy.totalOpen,
                  occupancy.totalCapacity,
                )
              : l10n.reportsOpenSessions(occupancy.totalOpen),
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: Space.sm),
        CategoryBarList(
          items: [
            for (final category in occupancy.byCategory)
              CategoryBarItem(
                label: category.capacity > 0
                    ? '${category.categoryName} '
                          '(${category.count}/${category.capacity})'
                    : category.categoryName,
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

class _WhatsappMetric extends StatelessWidget {
  const _WhatsappMetric({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = warning
        ? Theme.of(context).colorScheme.error
        : textTheme.titleSmall?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelSmall),
        Text(value, style: textTheme.titleMedium?.copyWith(color: color)),
      ],
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({required this.delta, required this.previous});

  final int delta;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final color = delta > 0
        ? scheme.primary
        : delta < 0
        ? scheme.error
        : scheme.onSurfaceVariant;
    final sign = delta > 0 ? '+' : '';
    return Semantics(
      label: l10n.reportsVsPrevious('$sign$delta'),
      child: Row(
        children: [
          Icon(
            delta >= 0 ? Icons.trending_up : Icons.trending_down,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            l10n.reportsVsPrevious('$sign$delta'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
          const SizedBox(width: Space.sm),
          Text(
            l10n.reportsPreviousTotal(Formatters.money(previous)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
