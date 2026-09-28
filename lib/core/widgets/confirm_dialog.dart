import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Yes/no confirmation. [destructive] paints the confirm button with the
/// error colors. Resolve with [ConfirmDialog.show].
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.destructive = false,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final bool destructive;

  /// `true` only when the user explicitly confirmed.
  static Future<bool> show(BuildContext context, ConfirmDialog dialog) async =>
      await showDialog<bool>(context: context, builder: (_) => dialog) ??
      false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
