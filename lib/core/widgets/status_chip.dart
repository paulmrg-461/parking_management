import 'package:flutter/material.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';

enum StatusTone { success, warning, pending, neutral }

/// Compact outlined status label. Text uses the status color directly on
/// the surface, which [StatusColors] guarantees at ≥ 4.5:1.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  Color _color(BuildContext context) {
    final status = StatusColors.of(context);
    return switch (tone) {
      StatusTone.success => status.success,
      StatusTone.warning => status.warning,
      StatusTone.pending => status.pending,
      StatusTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: Space.xs),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
