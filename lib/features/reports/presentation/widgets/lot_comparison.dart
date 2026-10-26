import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/revenue_report.dart';

/// Bars comparing every site's revenue, with its share of the total and the
/// average ticket. Shown only in the consolidated report.
class LotComparison extends StatelessWidget {
  const LotComparison({super.key, required this.lots});

  final List<LotRevenue> lots;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sorted = [...lots]..sort((a, b) => b.amount.compareTo(a.amount));
    final total = sorted.fold<int>(0, (sum, lot) => sum + lot.amount);
    final max = sorted.isEmpty ? 0 : sorted.first.amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lot in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Semantics(
              label: '${lot.lotName}: ${Formatters.money(lot.amount)}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(lot.lotName, style: textTheme.titleSmall),
                      ),
                      Text(
                        Formatters.money(lot.amount),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : lot.amount / max,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n.reportsLotTickets(lot.tickets)} · '
                          '${l10n.reportsLotAverage(Formatters.money(lot.avgTicket))}',
                          style: textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        total == 0
                            ? '—'
                            : l10n.reportsLotShare(
                                (lot.amount * 100 / total).round(),
                              ),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
