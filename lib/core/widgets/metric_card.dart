import 'package:flutter/material.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';

/// Semantic intent of a [MetricCard]; drives the icon tint only, never the
/// value color (numeric text keeps the theme's contrast).
enum MetricTone { neutral, primary, success, warning, danger }

/// KPI tile shared by the dashboard, reports, shifts and history: a label, a
/// big tabular value, an optional caption and a tonal icon. When [onTap] is
/// set the whole card is a ≥ 48 dp target with a tooltip-free semantics label.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = MetricTone.neutral,
    this.caption,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final MetricTone tone;
  final String? caption;

  /// Extra widget under the value (a chip, a mini sparkline, ...).
  final Widget? trailing;
  final VoidCallback? onTap;

  Color _accent(BuildContext context) {
    final status = StatusColors.of(context);
    return switch (tone) {
      MetricTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
      MetricTone.primary => Theme.of(context).colorScheme.primary,
      MetricTone.success => status.success,
      MetricTone.warning => status.warning,
      MetricTone.danger => Theme.of(context).colorScheme.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _accent(context);
    final card = Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (caption case final caption?)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (trailing case final trailing?)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: trailing,
                  ),
              ],
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: Space.sm),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$label: $value${caption == null ? '' : '. $caption'}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Layout.minTouch),
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? card
              : InkWell(onTap: onTap, child: card),
        ),
      ),
    );
  }
}
