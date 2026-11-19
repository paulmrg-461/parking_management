import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../application/reports_cubit.dart';
import '../../domain/entities/forecast_backtest.dart';

/// "Precisión del pronóstico": the forecast replayed over past weeks, next to
/// the profile alone. Computed on demand — it is the heaviest read.
class ForecastAccuracySection extends StatelessWidget {
  const ForecastAccuracySection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ReportsCubit>();
    return BlocBuilder<ReportsCubit, ReportsState>(
      buildWhen: (previous, current) =>
          previous is! ReportsLoaded ||
          current is! ReportsLoaded ||
          previous.backtest != current.backtest ||
          previous.backtestLoading != current.backtestLoading ||
          previous.backtestFailed != current.backtestFailed,
      builder: (context, state) {
        final loaded = state is ReportsLoaded ? state : null;
        final loading = loaded?.backtestLoading ?? false;
        final failed = loaded?.backtestFailed ?? false;
        final backtest = loaded?.backtest ?? ForecastBacktest.empty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              icon: Icons.insights_outlined,
              title: l10n.reportsForecastTitle,
              subtitle: l10n.reportsForecastSubtitle,
            ),
            const SizedBox(height: Space.sm),
            if (loading)
              const _BacktestSkeleton()
            else if (failed)
              EmptyState(
                icon: Icons.error_outline,
                title: l10n.reportsForecastUnavailable,
                message: l10n.reportsForecastSubtitle,
                action: OutlinedButton(
                  onPressed: () => cubit.loadBacktest(),
                  child: Text(l10n.actionRetry),
                ),
              )
            else if (!backtest.hasData)
              EmptyState(
                icon: Icons.insights_outlined,
                title: l10n.reportsForecastEmpty,
                message: l10n.reportsForecastSubtitle,
                action: FilledButton(
                  key: const Key('forecast-backtest-run'),
                  onPressed: () => cubit.loadBacktest(),
                  child: Text(l10n.reportsForecastRun),
                ),
              )
            else ...[
              for (final group in backtest.groups)
                if (group.points > 0) ...[
                  _GroupRow(group: group),
                  const SizedBox(height: Space.sm),
                ],
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const Key('forecast-backtest-rerun'),
                  onPressed: () => cubit.loadBacktest(),
                  child: Text(l10n.reportsForecastRun),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group});

  final BacktestGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final improvement = group.improvement;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MetricCard(
              icon: group.group == 'moto'
                  ? Icons.two_wheeler_outlined
                  : Icons.directions_car_outlined,
              label: group.group == 'moto'
                  ? l10n.publicForecastGroupMoto
                  : l10n.publicForecastGroupCar,
              value: _number(group.mae),
              caption: l10n.reportsForecastMae(_number(group.mae)),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: MetricCard(
              icon: Icons.history,
              label: l10n.reportsForecastPriorOnly(_number(group.maePriorOnly)),
              value: _number(group.maePriorOnly),
              caption: group.isBetter && improvement != null
                  ? l10n.reportsForecastBetter(improvement)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _number(double? value) =>
      value == null ? '—' : value.toStringAsFixed(2);
}

class _BacktestSkeleton extends StatelessWidget {
  const _BacktestSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
    );
  }
}

/// Compact chip telling whether the live blend helped (`null` without data).
Widget? forecastBetterChip(BuildContext context, BacktestGroup group) {
  final improvement = group.improvement;
  if (!group.isBetter || improvement == null) {
    return null;
  }
  return StatusChip(
    label: context.l10n.reportsForecastBetter(improvement),
    tone: StatusTone.success,
  );
}
