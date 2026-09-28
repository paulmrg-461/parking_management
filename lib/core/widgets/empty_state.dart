import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'centered_scrollable.dart';

/// Friendly "nothing here yet" placeholder, scrollable so a surrounding
/// RefreshIndicator still works.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CenteredScrollable(
      children: [
        Icon(icon, size: Space.xxl, color: scheme.onSurfaceVariant),
        const SizedBox(height: Space.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (action != null) ...[const SizedBox(height: Space.md), action!],
      ],
    );
  }
}
