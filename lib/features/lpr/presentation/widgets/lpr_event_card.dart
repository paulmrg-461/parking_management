import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/date_time_text.dart';
import '../../../../core/widgets/plate_text.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/lpr_event.dart';

/// One pending read. The plate is the headline; the reason chip explains why
/// a person is needed. The actions available depend on the direction and the
/// reason (an unpaid exit opens the check-out, never closes anything here).
class LprEventCard extends StatelessWidget {
  const LprEventCard({
    super.key,
    required this.event,
    this.onConfirm,
    this.onDismiss,
    this.onCheckOut,
  });

  final LprEvent event;
  final VoidCallback? onConfirm;
  final VoidCallback? onDismiss;
  final VoidCallback? onCheckOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final percent = (event.confidence * 100).round();
    return Card(
      key: Key('lpr_event_${event.id}'),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: PlateText(event.plate, size: PlateSize.large)),
                StatusChip(
                  label: _reasonLabel(l10n),
                  tone: event.isBlocked ? StatusTone.warning : StatusTone.pending,
                  icon: event.isBlocked
                      ? Icons.block_outlined
                      : _reasonIcon(event.reason),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              l10n.gateConfidence(percent),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Space.xs),
            Text(
              l10n.gateVotes(event.votes),
              style: theme.textTheme.bodySmall,
            ),
            if (event.deviceName.isNotEmpty) ...[
              const SizedBox(height: Space.xs),
              Text(
                l10n.gateDevice(event.deviceName),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: Space.xs),
            DateTimeText(event.createdAt, style: theme.textTheme.bodySmall),
            const SizedBox(height: Space.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: Space.sm,
              runSpacing: Space.xs,
              children: [
                if (onDismiss case final dismiss?)
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      key: Key('lpr_dismiss_${event.id}'),
                      onPressed: dismiss,
                      child: Text(l10n.gateDismiss),
                    ),
                  ),
                if (onConfirm case final confirm?)
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: Key('lpr_confirm_${event.id}'),
                      onPressed: confirm,
                      child: Text(l10n.gateConfirmEntry),
                    ),
                  ),
                if (onCheckOut case final checkOut?)
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: Key('lpr_checkout_${event.id}'),
                      onPressed: checkOut,
                      child: Text(l10n.gateOpenCheckOut),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _reasonLabel(AppLocalizations l10n) => switch (event.reason) {
    LprEventReason.assistMode => l10n.gateReasonAssist,
    LprEventReason.lowConfidence => l10n.gateReasonLowConfidence,
    LprEventReason.unknownPlate => l10n.gateReasonUnknownPlate,
    LprEventReason.noSystemOperator => l10n.gateReasonNoSystemOperator,
    LprEventReason.duplicateSession => l10n.gateReasonDuplicateSession,
    LprEventReason.lotFull => l10n.gateReasonLotFull,
    LprEventReason.error => l10n.gateReasonError,
    LprEventReason.blacklisted => l10n.gateReasonBlacklisted,
    LprEventReason.exitUnpaid => l10n.gateReasonExitUnpaid,
    LprEventReason.exitPaid => l10n.gateReasonExitPaid,
    LprEventReason.noOpenSession => l10n.gateReasonNoOpenSession,
    null => l10n.gateTitle,
  };

  IconData _reasonIcon(LprEventReason? reason) => switch (reason) {
    LprEventReason.blacklisted => Icons.block_outlined,
    LprEventReason.exitUnpaid => Icons.logout_outlined,
    LprEventReason.duplicateSession => Icons.repeat_outlined,
    LprEventReason.lotFull => Icons.garage_outlined,
    LprEventReason.lowConfidence => Icons.blur_on_outlined,
    _ => Icons.videocam_outlined,
  };
}
