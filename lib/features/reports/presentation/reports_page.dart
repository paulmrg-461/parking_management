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
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
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
          const SyncBadge(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: FilterBar(
              summary:
                  '${Formatters.date(_range.start)} — '
                  '${Formatters.date(_range.end)}',
              children: [
                SegmentedButton<_RangePreset>(
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
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: Layout.minTouch,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => _pickRange(context),
                    icon: const Icon(Icons.date_range),
                    label: Text(l10n.reportsRangeTooltip),
                  ),
                ),
                Tooltip(
                  message: l10n.reportsAllLotsHint,
                  child: FilterChip(
                    selected: _allLots,
                    showCheckmark: false,
                    avatar: const Icon(Icons.location_city_outlined, size: 18),
                    label: Text(l10n.reportsAllLots),
                    onSelected: (value) {
                      setState(() => _allLots = value);
                      _load();
                    },
                  ),
                ),
              ],
            ),
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
    final occupancyLabel = occupancy.totalCapacity > 0
        ? l10n.reportsOccupancyOf(
            occupancy.totalOpen,
            occupancy.totalCapacity,
          )
        : l10n.reportsOpenSessions(occupancy.totalOpen);
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        MetricCard(
          icon: Icons.payments_outlined,
          tone: MetricTone.primary,
          label: l10n.reportsTotalRevenue,
          value: Formatters.money(revenue.total),
          caption: l10n.monthlyPassPeriod(
            Formatters.date(range.start),
            Formatters.date(range.end),
          ),
          trailing: loaded.deltaPercent == null
              ? null
              : _DeltaRow(
                  delta: loaded.deltaPercent!,
                  previous: loaded.previousTotal!,
                ),
        ),
        if (revenue.passRevenue > 0 || revenue.totalDiscounts > 0) ...[
          const SizedBox(height: Space.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (revenue.passRevenue > 0)
                  Expanded(
                    child: MetricCard(
                      icon: Icons.card_membership,
                      label: l10n.reportsPassRevenue,
                      value: Formatters.money(revenue.passRevenue),
                    ),
                  ),
                if (revenue.passRevenue > 0 && revenue.totalDiscounts > 0)
                  const SizedBox(width: Space.sm),
                if (revenue.totalDiscounts > 0)
                  Expanded(
                    child: MetricCard(
                      icon: Icons.percent,
                      label: l10n.reportsTotalDiscounts,
                      value: Formatters.money(revenue.totalDiscounts),
                      caption: l10n.reportsDiscountedSessions(
                        revenue.discountedSessions,
                      ),
                      tone: MetricTone.warning,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (loaded.allLots && revenue.byLot.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.location_city_outlined,
            title: l10n.reportsByLot,
          ),
          const SizedBox(height: Space.sm),
          LotComparison(lots: revenue.byLot),
        ],
        if (revenue.discountAudit.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.percent,
            title: l10n.reportsDiscountLog,
            action: Text(
              '${revenue.discountAudit.length}',
              style: textTheme.labelMedium,
            ),
          ),
          for (final discount in revenue.discountAudit)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.percent, size: 20),
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
        if (revenue.passByPayment.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.card_membership,
            title: l10n.reportsPassRevenue,
          ),
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
        const SizedBox(height: Space.lg),
        SectionHeader(
          icon: Icons.show_chart,
          title: l10n.reportsRevenueByDay,
        ),
        const SizedBox(height: Space.sm),
        RevenueByDayChart(byDay: revenue.byDay),
        const SizedBox(height: Space.lg),
        SectionHeader(
          icon: Icons.category_outlined,
          title: l10n.reportsRevenueByCategory,
        ),
        const SizedBox(height: Space.sm),
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
        if (revenue.byPayment.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.credit_card_outlined,
            title: l10n.reportsRevenueByPayment,
          ),
          const SizedBox(height: Space.sm),
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
        ],
        if (loaded.whatsapp.hasData) ...[
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.chat_outlined,
            title: l10n.reportsWhatsapp,
          ),
          const SizedBox(height: Space.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MetricCard(
                    icon: Icons.send_outlined,
                    label: l10n.reportsWhatsappSent,
                    value: '${loaded.whatsapp.sent}',
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: MetricCard(
                    icon: Icons.error_outline,
                    label: l10n.reportsWhatsappFailed,
                    value: '${loaded.whatsapp.failed}',
                    tone: loaded.whatsapp.failed > 0
                        ? MetricTone.danger
                        : MetricTone.neutral,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: MetricCard(
                    icon: Icons.schedule,
                    label: l10n.reportsWhatsappPending,
                    value: '${loaded.whatsapp.pending}',
                  ),
                ),
              ],
            ),
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
        ],
        const SizedBox(height: Space.lg),
        SectionHeader(
          icon: Icons.local_parking_outlined,
          title: l10n.reportsOccupancy,
        ),
        const SizedBox(height: Space.sm),
        MetricCard(
          icon: Icons.directions_car_outlined,
          label: l10n.reportsOccupancy,
          value: occupancyLabel,
          caption: occupancy.totalCapacity > 0
              ? '${(occupancy.totalOpen * 100 / occupancy.totalCapacity).round()}%'
              : null,
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
