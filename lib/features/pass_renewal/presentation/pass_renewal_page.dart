import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../application/pass_renewal_cubit.dart';
import '../domain/entities/pass_renewal_checkout.dart';
import '../domain/entities/pass_renewal_offer.dart';

/// Public, token-keyed page behind the WhatsApp renewal button.
class PassRenewalPage extends StatefulWidget {
  const PassRenewalPage({super.key, this.token, this.launch});

  final String? token;

  /// Test seam; production opens the checkout in the same browser tab.
  final Future<bool> Function(Uri uri)? launch;

  @override
  State<PassRenewalPage> createState() => _PassRenewalPageState();
}

class _PassRenewalPageState extends State<PassRenewalPage> {
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  String get _token => (widget.token ?? '').trim();

  bool get _validToken => RegExp(r'^[0-9a-fA-F]{48}$').hasMatch(_token);

  Future<void> _start() async {
    final cubit = context.read<PassRenewalCubit>();
    if (!_validToken) {
      return;
    }
    await cubit.load(_token);
    if (!mounted) {
      return;
    }
    final state = cubit.state;
    if (state is PassRenewalReady &&
        state.offer.status.isOpen &&
        state.offer.paymentLinksEnabled) {
      // The customer may be back from the gateway: poll until the webhook
      // marks the offer paid (or the window closes).
      cubit.track(_token);
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
    if (!_validToken) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.passRenewalTitle)),
        body: Center(
          child: EmptyState(
            message: l10n.passRenewalUnavailable,
            icon: Icons.link_off,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.passRenewalTitle)),
      body: BlocConsumer<PassRenewalCubit, PassRenewalState>(
        listenWhen: (previous, current) {
          final next = _checkoutUrl(current);
          return next != null && next != _checkoutUrl(previous);
        },
        listener: (context, state) {
          final url = _checkoutUrl(state);
          if (url != null) {
            unawaited(_openCheckout(url));
          }
        },
        builder: (context, state) => switch (state) {
          PassRenewalInitial() ||
          PassRenewalLoading() => const SkeletonCardList(itemCount: 2),
          PassRenewalUnavailable() => Center(
            child: EmptyState(
              message: l10n.passRenewalUnavailable,
              icon: Icons.link_off,
            ),
          ),
          PassRenewalFailure(:final failure) => Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: ErrorState(
              message: l10n.failure(failure),
              onRetry: () => unawaited(_start()),
            ),
          ),
          PassRenewalReady(:final offer, :final submission) => _OfferBody(
            offer: offer,
            submission: submission,
            onPay: () => context.read<PassRenewalCubit>().pay(_token),
          ),
        },
      ),
    );
  }

  static String? _checkoutUrl(PassRenewalState state) {
    if (state is! PassRenewalReady) {
      return null;
    }
    final submission = state.submission;
    return submission is SubmissionSucceeded<PassRenewalCheckout>
        ? submission.result.checkoutUrl
        : null;
  }
}

class _OfferBody extends StatelessWidget {
  const _OfferBody({
    required this.offer,
    required this.submission,
    required this.onPay,
  });

  final PassRenewalOffer offer;
  final Submission submission;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final date = offer.renewalPeriodEnd ?? offer.periodEnd;
    final submitting = submission.isInProgress;
    final current = submission;
    final failed = current is SubmissionFailed ? current : null;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.lotName, style: theme.textTheme.titleMedium),
                const SizedBox(height: Space.xs),
                Text(
                  l10n.passRenewalPlate(offer.plateMasked),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: Space.md),
                if (offer.status.isPaid) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          l10n.passRenewalPaid(Formatters.date(date)),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    l10n.passRenewalPeriod(
                      Formatters.date(offer.periodStart),
                      Formatters.date(offer.periodEnd),
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(l10n.passRenewalAmount, style: theme.textTheme.bodySmall),
                  Text(
                    Money.formatAs(offer.currency, offer.amount),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  if (offer.paymentLinksEnabled)
                    FilledButton.icon(
                      key: const Key('pass_renewal_pay'),
                      onPressed: submitting ? null : onPay,
                      icon: submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_outline),
                      label: Text(
                        submitting
                            ? l10n.passRenewalChecking
                            : l10n.passRenewalPay,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    )
                  else
                    Text(
                      l10n.passRenewalPayAtDesk,
                      style: theme.textTheme.bodySmall,
                    ),
                  if (failed != null) ...[
                    const SizedBox(height: Space.sm),
                    ErrorState(
                      message: l10n.errorText(failed.message, failed.failure),
                      onRetry: onPay,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
