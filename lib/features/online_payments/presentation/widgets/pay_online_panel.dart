import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/state/submission.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../evidence/domain/entities/public_evidence.dart';
import '../../application/online_payment_cubit.dart';
import '../../domain/entities/payment_intent.dart';
import '../../domain/entities/payment_status.dart';

/// Public "pay from your phone" card. The amount is always the server's
/// `amount_due`; the customer only chooses the gateway.
class PayOnlinePanel extends StatefulWidget {
  const PayOnlinePanel({
    super.key,
    required this.summary,
    required this.plate,
    this.payReference,
    this.launch,
  });

  final PublicSessionSummary summary;

  /// Access key for the poll (the link never carries it).
  final String plate;

  /// `pay` query parameter after the gateway redirect.
  final String? payReference;

  /// Test seam; production opens the browser tab / external browser.
  final Future<bool> Function(Uri uri)? launch;

  @override
  State<PayOnlinePanel> createState() => _PayOnlinePanelState();
}

class _PayOnlinePanelState extends State<PayOnlinePanel> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<OnlinePaymentCubit>();
    cubit.prepare(widget.summary);
    final reference = widget.payReference;
    if (reference != null && reference.isNotEmpty) {
      cubit.track(reference: reference, plate: widget.plate);
    }
  }

  @override
  void didUpdateWidget(covariant PayOnlinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary != widget.summary) {
      context.read<OnlinePaymentCubit>().prepare(widget.summary);
    }
  }

  Future<void> _openCheckout(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    final launch =
        widget.launch ??
        (Uri target) => launchUrl(target, webOnlyWindowName: '_self');
    await launch(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocConsumer<OnlinePaymentCubit, OnlinePaymentState>(
      listenWhen: (previous, current) => submissionJustSucceeded(
        previous is OnlinePaymentReady ? previous.submission : null,
        current is OnlinePaymentReady ? current.submission : null,
      ),
      listener: (context, state) {
        if (state is! OnlinePaymentReady) {
          return;
        }
        final submission = state.submission;
        if (submission is SubmissionSucceeded<PaymentIntent>) {
          unawaited(_openCheckout(submission.result.checkoutUrl));
        }
      },
      builder: (context, state) => switch (state) {
        OnlinePaymentInitial() || OnlinePaymentLoading() => const _Card(
          child: SkeletonCard(),
        ),
        OnlinePaymentNothingDue() => const SizedBox.shrink(),
        OnlinePaymentFailure(:final failure) => _Card(
          child: ErrorState(
            message: l10n.failure(failure),
            onRetry: () => context.read<OnlinePaymentCubit>().prepare(
              widget.summary,
            ),
          ),
        ),
        OnlinePaymentReady ready => _Ready(
          state: ready,
          summary: widget.summary,
          plate: widget.plate,
          onPay: () => context.read<OnlinePaymentCubit>().pay(
            sessionId: widget.summary.sessionId,
            plate: widget.plate,
          ),
          card: _Card.new,
          hintStyle: theme.textTheme.bodySmall,
        ),
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: Space.md),
      color: scheme.surfaceContainerHighest,
      child: Padding(padding: const EdgeInsets.all(Space.md), child: child),
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({
    required this.state,
    required this.summary,
    required this.plate,
    required this.onPay,
    required this.card,
    required this.hintStyle,
  });

  final OnlinePaymentReady state;
  final PublicSessionSummary summary;
  final String plate;
  final VoidCallback onPay;
  final Widget Function({required Widget child}) card;
  final TextStyle? hintStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final submission = state.submission;
    final busy = submission.isInProgress;
    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_outlined, color: scheme.primary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  l10n.onlinePayTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            l10n.onlinePayDue,
            style: hintStyle,
          ),
          Text(
            Money.formatAs(summary.currency, state.amountDue),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
            ),
          ),
          if (state.isApproved) ...[
            const SizedBox(height: Space.sm),
            _StatusLine(
              icon: Icons.check_circle_outline,
              color:
                  Theme.of(context).extension<StatusColors>()?.success ??
                  scheme.primary,
              text: l10n.onlinePayApproved,
            ),
            if (state.graceUntil != null) ...[
              const SizedBox(height: Space.xs),
              _StatusLine(
                icon: Icons.schedule_outlined,
                color: scheme.primary,
                text: l10n.onlinePayGraceUntil(
                  Formatters.time(state.graceUntil!),
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(l10n.onlinePayLate, style: hintStyle),
            ],
          ] else ...[
            if (state.status == PaymentStatus.pending ||
                state.status == PaymentStatus.expired)
              _StatusLine(
                icon: Icons.hourglass_empty,
                color: scheme.onSurfaceVariant,
                text: l10n.onlinePayPending,
              ),
            if (state.status == PaymentStatus.declined ||
                state.status == PaymentStatus.error ||
                state.status == PaymentStatus.voided)
              _StatusLine(
                icon: Icons.error_outline,
                color: scheme.error,
                text: l10n.onlinePayDeclined,
              ),
            const SizedBox(height: Space.sm),
            FilledButton.icon(
              key: const Key('online_pay_action'),
              onPressed: busy ? null : onPay,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text(l10n.onlinePayAction),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(l10n.onlinePayHint(state.graceMinutes), style: hintStyle),
            if (submission is SubmissionSucceeded<PaymentIntent>) ...[
              const SizedBox(height: Space.xs),
              Text(l10n.onlinePayChecking, style: hintStyle),
            ],
            if (submission is SubmissionFailed) ...[
              const SizedBox(height: Space.sm),
              ErrorState(
                message: l10n.errorText(
                  submission.message,
                  submission.failure,
                ),
                onRetry: onPay,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: Space.sm),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ),
    ],
  );
}
