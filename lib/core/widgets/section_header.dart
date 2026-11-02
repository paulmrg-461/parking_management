import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Section title inside a page body: a tonal icon chip, the title and an
/// optional trailing action. Every form/list group uses this so the vertical
/// rhythm and type scale stay identical across modules.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.action,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;

  /// Trailing widget (usually a `TextButton.icon` or a counter chip).
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: Space.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle case final subtitle?)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (action case final action?)
            Padding(
              padding: const EdgeInsets.only(left: Space.sm),
              child: action,
            ),
        ],
      ),
    );
  }
}
