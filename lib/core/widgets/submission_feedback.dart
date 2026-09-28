import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Shows an action error as a SnackBar (the list underneath stays visible).
void showErrorSnack(BuildContext context, String message) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: scheme.onError)),
        backgroundColor: scheme.error,
      ),
    );
}

/// Shows a neutral confirmation SnackBar.
void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Confirmation with a "Deshacer" action (reversible changes only).
void showUndoSnack(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: context.l10n.actionUndo,
          onPressed: onUndo,
        ),
      ),
    );
}
