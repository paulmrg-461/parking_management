import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../domain/entities/fare_pricing.dart';

/// One breakdown row for the locked dynamic-pricing rule.
class AppliedRuleTile extends StatelessWidget {
  const AppliedRuleTile({super.key, required this.pricing});

  final FarePricing pricing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final percent = pricing.percentDelta >= 0
        ? '+${pricing.percentDelta} %'
        : '${pricing.percentDelta} %';
    final tone = pricing.delta >= 0
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Padding(
      key: const Key('applied_rule_tile'),
      padding: const EdgeInsets.only(top: Space.xs),
      child: Row(
        children: [
          Icon(Icons.trending_up_outlined, size: 15, color: tone),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              l10n.farePricingRule(pricing.ruleName, percent),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            '${pricing.delta >= 0 ? '+' : '-'}${Money.format(pricing.delta.abs())}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tone,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
