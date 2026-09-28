import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum AppIconButtonVariant { standard, filledTonal }

/// Icon button with a REQUIRED tooltip (its accessible name) and a 48dp
/// minimum target.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppIconButtonVariant.standard,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;

  static const _constraints = BoxConstraints(
    minWidth: Layout.minTouch,
    minHeight: Layout.minTouch,
  );

  @override
  Widget build(BuildContext context) => switch (variant) {
    AppIconButtonVariant.standard => IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: _constraints,
    ),
    AppIconButtonVariant.filledTonal => IconButton.filledTonal(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: _constraints,
    ),
  };
}
