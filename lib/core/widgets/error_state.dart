import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'centered_scrollable.dart';

/// Load error with a retry button; the message is announced (live region).
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CenteredScrollable(
      children: [
        Icon(Icons.cloud_off_outlined, size: Space.xxl, color: scheme.error),
        const SizedBox(height: Space.md),
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: Space.md),
        FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.actionRetry),
        ),
      ],
    );
  }
}
