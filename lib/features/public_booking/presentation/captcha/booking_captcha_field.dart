import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';

/// The "security check" block of the booking form: a label, the captcha
/// widget itself and, when something went wrong (not solved yet, expired,
/// failed), the reason with a retry that renders a fresh challenge.
class BookingCaptchaField extends StatelessWidget {
  const BookingCaptchaField({
    super.key,
    required this.captcha,
    required this.onRetry,
    this.message,
    this.canRetry = false,
  });

  /// The challenge (Turnstile on the web).
  final Widget captcha;

  /// Why the form cannot be sent yet; `null` when there is nothing to say.
  final String? message;

  /// Whether [message] is a failure the customer can retry (expired/failed),
  /// as opposed to "solve it first".
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.bookingCaptchaLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Space.xs),
        captcha,
        if (message != null) ...[
          const SizedBox(height: Space.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
          if (canRetry)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.actionRetry),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ),
        ],
      ],
    );
  }
}
