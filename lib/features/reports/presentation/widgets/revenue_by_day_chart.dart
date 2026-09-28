import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/cop_formatter.dart';
import '../../domain/entities/revenue_report.dart';
import '../report_colors.dart';

/// Column chart of revenue by day: a single series (no legend needed, per
/// the dataviz skill's series-count ladder), sequential blue, thin bars with
/// a 4px rounded data-end, hairline muted baseline, and a per-bar hover/
/// long-press tooltip standing in for the skill's mandatory hover layer.
/// The one value that matters most (the peak day) is direct-labeled; the
/// rest stay in the tooltip so the chart never floods with per-point labels.
class RevenueByDayChart extends StatelessWidget {
  const RevenueByDayChart({super.key, required this.byDay});

  final List<DailyRevenue> byDay;

  static const _barMaxWidth = 24.0;
  static const _chartHeight = 160.0;

  @override
  Widget build(BuildContext context) {
    if (byDay.isEmpty) {
      return Center(child: Text(context.l10n.reportsNoRevenue));
    }
    final maxAmount = byDay
        .map((d) => d.amount)
        .fold<int>(0, (max, amount) => amount > max ? amount : max);
    final barColor = ReportColors.sequential(context);
    final axisStyle = _axisStyle(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: ReportColors.chartSurface(context),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            maxAmount == 0 ? '' : CopFormatter.format(maxAmount),
            style: axisStyle,
          ),
          SizedBox(
            height: _chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in byDay)
                  Expanded(
                    child: _Bar(
                      day: day,
                      maxAmount: maxAmount,
                      isPeak: maxAmount > 0 && day.amount == maxAmount,
                      color: barColor,
                      chartHeight: _chartHeight,
                      barMaxWidth: _barMaxWidth,
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: ReportColors.baseline(context)),
          const SizedBox(height: Space.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_shortDate(byDay.first.date), style: axisStyle),
              if (byDay.length > 1)
                Text(_shortDate(byDay.last.date), style: axisStyle),
            ],
          ),
        ],
      ),
    );
  }

  /// `labelSmall` so axis text follows the user's text scale.
  static TextStyle? _axisStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: ReportColors.mutedText(context));

  static String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.maxAmount,
    required this.isPeak,
    required this.color,
    required this.chartHeight,
    required this.barMaxWidth,
  });

  final DailyRevenue day;
  final int maxAmount;
  final bool isPeak;
  final Color color;
  final double chartHeight;
  final double barMaxWidth;

  static const _minBar = 2.0;
  static const _barWidthFactor = 0.7;

  /// Room for the peak label at the current text scale.
  static double _labelReserve(BuildContext context, TextStyle? style) {
    final fontSize = style?.fontSize ?? 11;
    final scaled = MediaQuery.textScalerOf(context).scale(fontSize);
    return (scaled * (style?.height ?? 1.5)).ceilToDouble() + Space.xs;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmount == 0 ? 0.0 : day.amount / maxAmount;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: ReportColors.primaryText(context),
    );
    // Every bar reserves the label room so all share one scale.
    final reserve = _labelReserve(context, labelStyle);
    final barHeight = ((chartHeight - reserve) * ratio).clamp(
      _minBar,
      chartHeight,
    );
    return Tooltip(
      message:
          '${RevenueByDayChart._shortDate(day.date)}: ${CopFormatter.format(day.amount)}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isPeak)
            Text(
              CopFormatter.format(day.amount),
              style: labelStyle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          if (isPeak) const SizedBox(height: Space.xs),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: barMaxWidth),
            child: FractionallySizedBox(
              widthFactor: _barWidthFactor,
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Space.xs),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
