import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/cop_formatter.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/check_out_preview.dart';

/// Explains a fare preview: how long the car stayed, the hours billed per day
/// and night window, any daily cap, and the total. Server numbers only.
class FareBreakdownView extends StatelessWidget {
  const FareBreakdownView({
    super.key,
    required this.preview,
    this.showTime = true,
  });

  final CheckOutPreview preview;

  /// The live sheet shows its own ticking clock, so it hides this static row.
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTime)
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: muted),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  l10n.fareTime(Formatters.duration(l10n, preview.elapsed)),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (preview.days > 1)
                Text(
                  l10n.fareDays(preview.days),
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
            ],
          ),
        if (!preview.hasPass && preview.dayHours > 0)
          _Line(
            text: l10n.fareDayHours(
              preview.dayHours,
              CopFormatter.format(preview.hourlyRate ?? 0),
            ),
          ),
        if (!preview.hasPass && preview.nightHours > 0)
          _Line(
            text: l10n.fareNightHours(
              preview.nightHours,
              CopFormatter.format(preview.nightlyRate ?? 0),
            ),
          ),
        if (preview.dailyCapApplied)
          _Line(
            icon: Icons.savings_outlined,
            text: l10n.fareDailyCap(
              CopFormatter.format(preview.dailyRate ?? 0),
            ),
            tone: StatusColors.of(context).success,
          ),
        if (preview.hasPass)
          _Line(
            icon: Icons.card_membership,
            text: l10n.checkOutPassCovered,
            tone: StatusColors.of(context).success,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Divider(height: 1, color: theme.dividerColor),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.fareTotal,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              CopFormatter.format(preview.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, this.icon, this.tone});

  final String text;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tone ?? theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: Space.xs),
          ] else
            const SizedBox(width: 20),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
