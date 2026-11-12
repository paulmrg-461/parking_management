import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/period_comparison.dart';

/// Monthly comparison against the previous month and the same month last year.
///
/// Facts come from the server; the chips are decided here by [periodDelta], so
/// a month without a usable base simply says so instead of inventing a number.
class PeriodComparisonSection extends StatefulWidget {
  const PeriodComparisonSection({
    super.key,
    required this.comparison,
    required this.months,
    required this.onMonthsChanged,
    required this.onRetry,
    this.loading = false,
    this.failed = false,
    this.activeLotOnly = false,
  });

  final PeriodComparison comparison;
  final int months;
  final ValueChanged<int> onMonthsChanged;
  final VoidCallback onRetry;
  final bool loading;
  final bool failed;
  final bool activeLotOnly;

  @override
  State<PeriodComparisonSection> createState() =>
      _PeriodComparisonSectionState();
}

class _PeriodComparisonSectionState extends State<PeriodComparisonSection> {
  PeriodMetric _metric = PeriodMetric.revenue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.calendar_month_outlined,
          title: l10n.reportsPeriodTitle,
          subtitle: widget.activeLotOnly
              ? l10n.reportsPeriodActiveLotOnly
              : l10n.reportsPeriodSubtitle,
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final months in const [6, 12])
              ChoiceChip(
                key: Key('period-months-$months'),
                label: Text(l10n.reportsPeriodMonths(months)),
                selected: widget.months == months,
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => widget.onMonthsChanged(months),
              ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<PeriodMetric>(
                key: const Key('period-metric'),
                initialValue: _metric,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.reportsPeriodMetricLabel,
                ),
                items: [
                  for (final metric in PeriodMetric.values)
                    DropdownMenuItem(
                      value: metric,
                      child: Text(
                        _metricLabel(l10n, metric),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (metric) {
                  if (metric != null) {
                    setState(() => _metric = metric);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        if (widget.loading)
          const _PeriodSkeleton()
        else if (widget.failed)
          EmptyState(
            icon: Icons.cloud_off_outlined,
            message: l10n.reportsPeriodUnavailable,
            action: TextButton(
              key: const Key('period-retry'),
              onPressed: widget.onRetry,
              child: Text(l10n.actionRetry),
            ),
          )
        else if (!widget.comparison.hasData)
          EmptyState(
            icon: Icons.calendar_month_outlined,
            title: l10n.reportsPeriodEmptyTitle,
            message: l10n.reportsPeriodEmpty,
          )
        else
          _Loaded(comparison: widget.comparison, metric: _metric),
      ],
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.comparison, required this.metric});

  final PeriodComparison comparison;
  final PeriodMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final latest = comparison.latest!;
    final current = latest.current;
    final monthDelta = latest.deltaVsMonth(metric);
    final yearDelta = latest.deltaVsYear(metric);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodChart(comparison: comparison, metric: metric),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.md,
          runSpacing: Space.xs,
          children: [
            _Legend(
              color: theme.colorScheme.primary,
              label: l10n.reportsPeriodLegendCurrent,
            ),
            _Legend(
              color: theme.colorScheme.outlineVariant,
              label: l10n.reportsPeriodLegendLastYear,
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        MetricCard(
          icon: Icons.insights_outlined,
          label: _metricLabel(l10n, metric),
          value: _formatValue(l10n, metric, current.valueOf(metric)),
          caption: latest.isPartial
              ? l10n.reportsPeriodPartial(
                  current.days,
                  _daysInMonth(latest.month),
                )
              : null,
        ),
        if (latest.isPartial) ...[
          const SizedBox(height: Space.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(
              key: const Key('period-partial-chip'),
              label: l10n.reportsPeriodPartialChip,
              tone: StatusTone.pending,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            l10n.reportsPeriodPartialHint(current.days),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            _DeltaChip(
              delta: monthDelta,
              metric: metric,
              label: l10n.reportsPeriodVsMonth,
              flat: l10n.reportsPeriodFlatMonth,
            ),
            _DeltaChip(
              delta: yearDelta,
              metric: metric,
              label: l10n.reportsPeriodVsYear,
              flat: l10n.reportsPeriodFlatYear,
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        for (final bucket in comparison.buckets.reversed)
          _PeriodRow(bucket: bucket, metric: metric),
      ],
    );
  }
}

class _PeriodChart extends StatelessWidget {
  const _PeriodChart({required this.comparison, required this.metric});

  final PeriodComparison comparison;
  final PeriodMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final peak = comparison.peakOf(metric);
    const chartHeight = 96.0;
    final groups = [
      for (final bucket in comparison.buckets)
        _BarGroup(
          key: Key('period-bar-${bucket.monthKey}'),
          label: _monthLabel(l10n, bucket.month),
          current: bucket.current.valueOf(metric),
          previous: bucket.previousYear.valueOf(metric),
          partial: bucket.isPartial,
          peak: peak,
          height: chartHeight,
          semantics: l10n.reportsPeriodBarSemantics(
            _monthLabel(l10n, bucket.month),
            _formatValue(l10n, metric, bucket.current.valueOf(metric)),
            _formatValue(l10n, metric, bucket.previousYear.valueOf(metric)),
          ),
        ),
    ];
    return SingleChildScrollView(
      key: const Key('period-chart'),
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final group in groups) ...[
            group,
            const SizedBox(width: Space.sm),
          ],
        ],
      ),
    );
  }
}

class _BarGroup extends StatelessWidget {
  const _BarGroup({
    super.key,
    required this.label,
    required this.current,
    required this.previous,
    required this.partial,
    required this.peak,
    required this.height,
    required this.semantics,
  });

  final String label;
  final int current;
  final int previous;
  final bool partial;
  final int peak;
  final double height;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    double bar(int value) => peak <= 0 ? 2 : math.max(2, height * value / peak);
    return Semantics(
      label: semantics,
      child: SizedBox(
        width: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: bar(current),
                    decoration: BoxDecoration(
                      color: partial ? scheme.tertiary : scheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(Radii.sm),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 12,
                    height: bar(previous),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(Radii.sm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.delta,
    required this.metric,
    required this.label,
    required this.flat,
  });

  final int? delta;
  final PeriodMetric metric;
  final String Function(String delta) label;
  final String flat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final value = delta;
    if (value == null) {
      return Text(
        l10n.reportsPeriodNoBase,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (value == 0) {
      return StatusChip(
        label: flat,
        tone: StatusTone.neutral,
        icon: Icons.trending_flat,
      );
    }
    final tone = metric == PeriodMetric.avgStay
        ? StatusTone.neutral
        : value > 0
        ? StatusTone.success
        : StatusTone.warning;
    return StatusChip(
      label: label('${value > 0 ? '+' : ''}$value %'),
      tone: tone,
      icon: value > 0
          ? Icons.trending_up
          : value < 0
          ? Icons.trending_down
          : Icons.trending_flat,
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.bucket, required this.metric});

  final PeriodBucket bucket;
  final PeriodMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final monthDelta = bucket.deltaVsMonth(metric);
    final yearDelta = bucket.deltaVsYear(metric);
    return Padding(
      key: Key('period-row-${bucket.monthKey}'),
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthLabel(l10n, bucket.month)} ${bucket.month.year}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Flexible(
                child: Text(
                  _formatValue(l10n, metric, bucket.current.valueOf(metric)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: Space.xs,
            runSpacing: 2,
            children: [
              if (bucket.isPartial)
                StatusChip(
                  label: l10n.reportsPeriodPartialChip,
                  tone: StatusTone.pending,
                ),
              _DeltaChip(
                delta: monthDelta,
                metric: metric,
                label: l10n.reportsPeriodVsMonth,
                flat: l10n.reportsPeriodFlatMonth,
              ),
              _DeltaChip(
                delta: yearDelta,
                metric: metric,
                label: l10n.reportsPeriodVsYear,
                flat: l10n.reportsPeriodFlatYear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodSkeleton extends StatelessWidget {
  const _PeriodSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonPulse(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(width: double.infinity, height: 96),
        SizedBox(height: Space.sm),
        SkeletonBox(width: 180, height: 16),
        SizedBox(height: Space.xs),
        SkeletonBox(width: 140, height: 16),
      ],
    ),
  );
}

String _metricLabel(AppLocalizations l10n, PeriodMetric metric) =>
    switch (metric) {
      PeriodMetric.revenue => l10n.reportsPeriodMetricRevenue,
      PeriodMetric.entries => l10n.reportsPeriodMetricEntries,
      PeriodMetric.exits => l10n.reportsPeriodMetricExits,
      PeriodMetric.avgTicket => l10n.reportsPeriodMetricAvgTicket,
      PeriodMetric.avgStay => l10n.reportsPeriodMetricAvgStay,
      PeriodMetric.passRevenue => l10n.reportsPeriodMetricPassRevenue,
      PeriodMetric.reservations => l10n.reportsPeriodMetricReservations,
    };

String _formatValue(AppLocalizations l10n, PeriodMetric metric, int value) =>
    switch (metric) {
      PeriodMetric.revenue ||
      PeriodMetric.avgTicket ||
      PeriodMetric.passRevenue => Formatters.money(value),
      PeriodMetric.avgStay => Formatters.duration(
        l10n,
        Duration(minutes: value),
      ),
      PeriodMetric.entries ||
      PeriodMetric.exits ||
      PeriodMetric.reservations => '$value',
    };

String _monthLabel(AppLocalizations l10n, DateTime month) =>
    DateFormat.MMM(l10n.localeName).format(month);

int _daysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;
