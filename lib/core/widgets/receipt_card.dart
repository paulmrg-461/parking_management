import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/status_colors.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Whether a receipt describes a vehicle entering or leaving.
enum ReceiptKind { checkIn, checkOut }

/// Display data for a [ReceiptCard]. Pure UI model: it is built from a
/// `CheckOutReceipt` or a `ParkingSession` at the call site.
class ReceiptData {
  const ReceiptData({
    required this.kind,
    required this.plate,
    required this.entryTime,
    this.exitTime,
    this.photoCount,
    this.amountCharged,
    this.ticketNumber,
    this.pendingSync = false,
  });

  final ReceiptKind kind;
  final String plate;
  final DateTime entryTime;
  final DateTime? exitTime;
  final int? photoCount;
  final int? amountCharged;
  final String? ticketNumber;
  final bool pendingSync;

  bool get isCheckOut => kind == ReceiptKind.checkOut;
}

/// Shows [data] as a polished receipt dialog (the "generar recibo" target).
Future<void> showReceipt(BuildContext context, ReceiptData data) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ReceiptDialog(data: data),
  );
}

/// Shows a compact, formatted summary with a "Generar recibo" action that
/// opens the full receipt via [showReceipt].
Future<void> showReceiptSummary(BuildContext context, ReceiptData data) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReceiptSummaryDialog(data: data),
  );
}

/// Compact post-action summary (check-in or check-out): formatted dates,
/// duration, a pretty amount and a "Generar recibo" button.
class ReceiptSummaryDialog extends StatelessWidget {
  const ReceiptSummaryDialog({super.key, required this.data});

  final ReceiptData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    final exitTime = data.exitTime;

    return Dialog(
      backgroundColor: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.maxForm),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                data.isCheckOut
                    ? l10n.receiptDoneTitle
                    : l10n.checkInReceiptTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                data.plate,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: Space.md),
              ReceiptRow(
                label: l10n.receiptEntry,
                value: Formatters.dateTimeFull(data.entryTime),
              ),
              if (data.isCheckOut && exitTime != null) ...[
                ReceiptRow(
                  label: l10n.receiptExit,
                  value: Formatters.dateTimeFull(exitTime),
                ),
                ReceiptRow(
                  label: l10n.receiptDuration,
                  value: Formatters.duration(
                    l10n,
                    exitTime.difference(data.entryTime),
                  ),
                  emphasized: true,
                ),
              ] else if (data.photoCount != null)
                ReceiptRow(
                  label: l10n.receiptPhotos,
                  value: l10n.sessionPhotos(data.photoCount!),
                ),
              const SizedBox(height: Space.md),
              if (data.pendingSync)
                _PendingNotice(message: l10n.receiptQueued, status: status)
              else if (data.isCheckOut && data.amountCharged != null)
                _AmountBlock(
                  amount: data.amountCharged!,
                  label: l10n.receiptAmount,
                ),
              if (data.isCheckOut &&
                  !data.pendingSync &&
                  data.ticketNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: ReceiptRow(
                    label: l10n.receiptTicket,
                    value: data.ticketNumber!,
                    valueStyle: theme.textTheme.labelLarge?.copyWith(
                      fontFamily: 'monospace',
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              const SizedBox(height: Space.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.receiptClose),
                  ),
                  const SizedBox(width: Space.sm),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showReceipt(context, data);
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: Text(l10n.receiptGenerate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({required this.data});

  final ReceiptData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.lg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.maxForm),
        child: Material(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(Radii.lg),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReceiptCard(data: data),
                  const SizedBox(height: Space.lg),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.receiptClose),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A polished receipt: header, dashed rule, detail rows, an emphasized
/// amount (check-out) or a pending-sync notice, and a footer signature.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({super.key, required this.data});

  final ReceiptData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(data: data),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: Space.md),
          child: _DashedDivider(),
        ),
        if (data.isCheckOut) ...[
          ReceiptRow(
            label: l10n.receiptEntry,
            value: Formatters.dateTimeFull(data.entryTime),
          ),
          if (data.exitTime != null)
            ReceiptRow(
              label: l10n.receiptExit,
              value: Formatters.dateTimeFull(data.exitTime!),
            ),
          if (data.exitTime != null)
            ReceiptRow(
              label: l10n.receiptDuration,
              value: Formatters.duration(
                l10n,
                data.exitTime!.difference(data.entryTime),
              ),
              emphasized: true,
            ),
        ] else ...[
          ReceiptRow(
            label: l10n.receiptEntry,
            value: Formatters.dateTimeFull(data.entryTime),
          ),
          if (data.photoCount != null)
            ReceiptRow(
              label: l10n.receiptPhotos,
              value: l10n.sessionPhotos(data.photoCount!),
            ),
        ],
        if (data.pendingSync)
          _PendingNotice(message: l10n.receiptQueued, status: status)
        else if (data.isCheckOut && data.amountCharged != null)
          _AmountBlock(amount: data.amountCharged!, label: l10n.receiptAmount),
        if (data.isCheckOut && !data.pendingSync && data.ticketNumber != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: ReceiptRow(
              label: l10n.receiptTicket,
              value: data.ticketNumber!,
              valueStyle: theme.textTheme.labelLarge?.copyWith(
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 1,
              ),
            ),
          ),
        const SizedBox(height: Space.lg),
        const Divider(height: 1),
        const SizedBox(height: Space.sm),
        Text(
          l10n.receiptGeneratedAt(Formatters.dateTimeFull(DateTime.now())),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final ReceiptData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);

    final IconData icon = data.isCheckOut
        ? (data.pendingSync ? Icons.sync_rounded : Icons.logout_rounded)
        : Icons.login_rounded;

    final circleColor = data.pendingSync
        ? status.pending.withValues(alpha: 0.15)
        : scheme.primaryContainer;
    final iconColor = data.pendingSync ? status.pending : scheme.onPrimaryContainer;

    final kicker = data.isCheckOut
        ? l10n.receiptDoneTitle
        : l10n.checkInReceiptTitle;

    return Column(
      children: [
        Container(
          width: Space.xxl,
          height: Space.xxl,
          decoration: BoxDecoration(shape: BoxShape.circle, color: circleColor),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(height: Space.sm),
        Text(
          kicker.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          data.plate,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A label → value row, used across receipt variants.
class ReceiptRow extends StatelessWidget {
  const ReceiptRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueStyle,
  });

  final String label;
  final String value;
  final bool emphasized;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = emphasized
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.bodyMedium;
    final effectiveValueStyle = (emphasized
            ? theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              )
            : theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500))
        ?.merge(valueStyle);

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                label,
                style: labelStyle?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: Space.md),
            Text(value, style: effectiveValueStyle),
          ],
        ),
      ),
    );
  }
}

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({required this.amount, required this.label});

  final int amount;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: Space.md),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Semantics(
        label: '$label ${Formatters.money(amount)}',
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              Formatters.money(amount),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingNotice extends StatelessWidget {
  const _PendingNotice({required this.message, required this.status});

  final String message;
  final StatusColors status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: Space.md),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      decoration: BoxDecoration(
        color: status.pending,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Semantics(
        label: message,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 18,
              color: status.onPending,
              semanticLabel: null,
            ),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                message,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: status.onPending,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashPainter(
          Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    const dashWidth = 6.0;
    const dashGap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, size.height / 2), Offset(end, size.height / 2), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}
