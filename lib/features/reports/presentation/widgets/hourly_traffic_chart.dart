import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/entities/hourly_traffic.dart';
import '../report_colors.dart';

/// Compact hourly heat grid: one cell per hour (00–23) with the entry count
/// and a bar scaled to the busiest hour. Exits are in the tooltip/semantics,
/// so the cell never relies on colour alone.
class HourlyTrafficChart extends StatelessWidget {
  const HourlyTrafficChart({super.key, required this.traffic});

  final HourlyTraffic traffic;

  static String hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    if (!traffic.hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Text(l10n.reportsHourlyEmpty, style: textTheme.bodyMedium),
      );
    }
    final peak = traffic.peak;
    final peakEntries = traffic.peakEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (peak != null)
          Row(
            children: [
              Icon(
                Icons.trending_up,
                size: 18,
                color: ReportColors.sequential(context),
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  l10n.reportsHourlyPeak(hourLabel(peak.hour), peak.entries),
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        const SizedBox(height: Space.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 8
                : constraints.maxWidth >= 480
                ? 6
                : 4;
            const gap = Space.sm;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final point in traffic.hours)
                  SizedBox(
                    width: width,
                    child: _HourCell(point: point, peakEntries: peakEntries),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: Space.xs),
        Text(
          l10n.reportsHourlyLegend,
          style: textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({required this.point, required this.peakEntries});

  final HourlyTrafficPoint point;
  final int peakEntries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = peakEntries == 0 ? 0.0 : point.entries / peakEntries;
    final semantic = l10n.reportsHourlyCell(
      HourlyTrafficChart.hourLabel(point.hour),
      point.entries,
      point.exits,
    );
    return Tooltip(
      message: semantic,
      child: Semantics(
        label: semantic,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    HourlyTrafficChart.hourLabel(point.hour).substring(0, 2),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text('${point.entries}', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: Space.xs),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: ratio.clamp(0, 1),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  color: ReportColors.sequential(context),
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
