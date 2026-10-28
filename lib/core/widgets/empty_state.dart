import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'centered_scrollable.dart';

/// Friendly "nothing here yet" placeholder, scrollable so a surrounding
/// RefreshIndicator still works. The optional [title] gives the state a clear
/// headline ("Sin resultados") above the guidance [message]; [action] is the
/// explicit next step required by the design system.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final String? title;
  final IconData icon;
  final Widget? action;

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
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: Space.xl, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Space.md),
        if (title case final title?)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: Space.md),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Layout.minTouch),
            child: action,
          ),
        ],
      ],
    );
  }
}
