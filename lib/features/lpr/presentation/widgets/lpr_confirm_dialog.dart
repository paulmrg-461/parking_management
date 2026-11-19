import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/widgets/plate_input_field.dart';
import '../../domain/entities/lpr_event.dart';

/// Lets the operator correct a misread plate before opening the session.
/// Returns the normalized plate, or null when cancelled.
Future<String?> showLprConfirmDialog(
  BuildContext context,
  LprEvent event,
) {
  return showDialog<String>(
    context: context,
    builder: (context) => _LprConfirmDialog(event: event),
  );
}

class _LprConfirmDialog extends StatefulWidget {
  const _LprConfirmDialog({required this.event});

  final LprEvent event;

  @override
  State<_LprConfirmDialog> createState() => _LprConfirmDialogState();
}

class _LprConfirmDialogState extends State<_LprConfirmDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.event.plate,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('lpr_confirm_dialog'),
      title: Text(l10n.gateConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.gateConfirmBody),
          const SizedBox(height: 12),
          PlateInputField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('lpr_confirm_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.gateDismiss),
        ),
        FilledButton(
          key: const Key('lpr_confirm_submit'),
          onPressed: _submit,
          child: Text(l10n.gateConfirmEntry),
        ),
      ],
    );
  }

  void _submit() {
    final plate = _controller.text.trim().toUpperCase();
    if (plate.length < 3) return;
    Navigator.of(context).pop(plate);
  }
}
