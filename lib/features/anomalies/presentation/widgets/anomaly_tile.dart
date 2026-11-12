import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/plate_text.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/cash_anomaly.dart';
import '../anomalies_page.dart';

/// One anomaly row: severity, rule, description, operator and the review
/// actions (>= 48 dp).
class AnomalyTile extends StatelessWidget {
  const AnomalyTile({
    super.key,
    required this.anomaly,
    required this.resolving,
    required this.onResolve,
    required this.onAudit,
  });

  final CashAnomaly anomaly;
  final bool resolving;
  final Future<void> Function(AnomalyStatus status, String? note) onResolve;
  final VoidCallback onAudit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: Key('anomaly-${anomaly.id}'),
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusChip(
                  label: anomalySeverityLabel(context, anomaly.severity),
                  tone: severityTone(anomaly.severity),
                  icon: anomaly.severity == AnomalySeverity.high
                      ? Icons.priority_high
                      : null,
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    anomalyRuleLabel(context, anomaly.rule),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  anomaly.detectedAt.toLocal().toString().substring(0, 16),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(anomalyDescription(context, anomaly)),
            if (anomaly.operatorName != null)
              Text(
                anomaly.operatorName!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (anomaly.plate != null && anomaly.plate!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: PlateText(anomaly.plate!),
              ),
            if (!anomaly.isOpen) ...[
              const SizedBox(height: Space.xs),
              Text(
                [
                  anomaly.resolvedByName ?? '',
                  anomaly.note ?? '',
                ].where((part) => part.isNotEmpty).join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.sm,
              children: [
                if (anomaly.isOpen) ...[
                  FilledButton(
                    key: Key('anomaly-ack-${anomaly.id}'),
                    onPressed: resolving
                        ? null
                        : () => showAnomalyResolveDialog(
                            context,
                            anomaly,
                            onResolve: onResolve,
                          ),
                    child: Text(l10n.anomalyAcknowledge),
                  ),
                  TextButton(
                    key: Key('anomaly-dismiss-${anomaly.id}'),
                    onPressed: resolving
                        ? null
                        : () => showAnomalyResolveDialog(
                            context,
                            anomaly,
                            onResolve: onResolve,
                          ),
                    child: Text(l10n.anomalyDismiss),
                  ),
                ],
                TextButton(
                  key: Key('anomaly-audit-${anomaly.id}'),
                  onPressed: onAudit,
                  child: Text(l10n.anomalyViewAudit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
