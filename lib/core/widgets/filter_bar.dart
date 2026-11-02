import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Rounded surface that groups search + filter controls above a list. Keeps
/// the same elevation/border as [MetricCard] so toolbars and KPIs read as one
/// family, and gives every control a ≥ 48 dp hit area.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.children,
    this.summary,
    this.onClear,
    this.clearLabel,
  });

  final List<Widget> children;

  /// Result count or active-range text shown before the controls.
  final String? summary;
  final VoidCallback? onClear;
  final String? clearLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary case final summary?)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...children,
              if (onClear != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Layout.minTouch),
                  child: TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: Text(clearLabel ?? ''),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
