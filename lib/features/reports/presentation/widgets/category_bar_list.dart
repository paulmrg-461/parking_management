import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../report_colors.dart';

/// One row of [CategoryBarList].
class CategoryBarItem {
  const CategoryBarItem({required this.label, required this.value});

  final String label;
  final int value;
}

/// Horizontal categorical bar list: part-to-whole breakdown by category.
/// A list/table beats a full chart-with-legend here because category counts
/// are small (per the dataviz skill's "more than ~7 classes -> table" and
/// "series 1-3 direct-label" guidance) - every row already carries its own
/// direct label (name + value), so a separate legend box would just repeat
/// it. Colors are the fixed-order validated categorical palette; labels
/// stay in text tokens, never in the series color, per the skill's mark
/// spec.
class CategoryBarList extends StatelessWidget {
  const CategoryBarList({
    super.key,
    required this.items,
    required this.formatValue,
  });

  final List<CategoryBarItem> items;
  final String Function(int) formatValue;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(context.l10n.reportsNoCategoryData));
    }
    final maxValue = items
        .map((i) => i.value)
        .fold<int>(0, (max, value) => value > max ? value : max);

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: Space.sm),
          _CategoryRow(
            item: items[i],
            color: ReportColors.categorical(context, i),
            ratio: maxValue == 0 ? 0.0 : items[i].value / maxValue,
            formatValue: formatValue,
          ),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.color,
    required this.ratio,
    required this.formatValue,
  });

  final CategoryBarItem item;
  final Color color;
  final double ratio;
  final String Function(int) formatValue;

  static const _swatch = 12.0;
  static const _track = 8.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Tooltip(
      message: '${item.label}: ${formatValue(item.value)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _swatch,
                height: _swatch,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(Space.xs),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  item.label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: ReportColors.secondaryText(context),
                  ),
                ),
              ),
              Text(
                formatValue(item.value),
                style: textTheme.titleSmall?.copyWith(
                  color: ReportColors.primaryText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(
                  height: _track,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: ReportColors.gridline(context),
                    borderRadius: BorderRadius.circular(Space.xs),
                  ),
                ),
                Container(
                  height: _track,
                  width: constraints.maxWidth * ratio,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(Space.xs),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
