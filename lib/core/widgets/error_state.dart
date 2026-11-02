import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'centered_scrollable.dart';

/// Load error with a retry button; the message is announced (live region).
/// The title separates "what happened" from "what to do"; the raw exception
/// text never reaches this widget (the cubit maps it to a localized message).
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
  });

  final String message;
  final VoidCallback onRetry;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CenteredScrollable(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_off_outlined,
            size: Space.xl,
            color: scheme.onErrorContainer,
          ),
        ),
        const SizedBox(height: Space.md),
        Text(
          title ?? context.l10n.errorTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Space.xs),
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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
