import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/fiscal_document.dart';

/// Status label of one fiscal document (theme colors only).
class FiscalStatusChip extends StatelessWidget {
  const FiscalStatusChip({super.key, required this.status});

  final FiscalStatus status;

  static String label(FiscalStatus status, AppLocalizations l10n) =>
      switch (status) {
        FiscalStatus.pending => l10n.invoicingStatusPending,
        FiscalStatus.sent => l10n.invoicingStatusSent,
        FiscalStatus.accepted => l10n.invoicingStatusAccepted,
        FiscalStatus.rejected => l10n.invoicingStatusRejected,
        FiscalStatus.failed => l10n.invoicingStatusFailed,
      };

  static StatusTone tone(FiscalStatus status) => switch (status) {
    FiscalStatus.accepted => StatusTone.success,
    FiscalStatus.pending || FiscalStatus.sent => StatusTone.pending,
    FiscalStatus.rejected || FiscalStatus.failed => StatusTone.warning,
  };

  @override
  Widget build(BuildContext context) => StatusChip(
    label: label(status, context.l10n),
    tone: tone(status),
  );
}
