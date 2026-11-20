import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../domain/entities/barrier.dart';

/// Asks for the mandatory reason (3..200 characters). Returns the trimmed
/// reason, or null when cancelled.
Future<String?> showOpenBarrierDialog(
  BuildContext context,
  Barrier barrier,
) {
  return showDialog<String>(
    context: context,
    builder: (context) => _OpenBarrierDialog(barrier: barrier),
  );
}

class _OpenBarrierDialog extends StatefulWidget {
  const _OpenBarrierDialog({required this.barrier});

  final Barrier barrier;

  @override
  State<_OpenBarrierDialog> createState() => _OpenBarrierDialogState();
}

class _OpenBarrierDialogState extends State<_OpenBarrierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final length = (value ?? '').trim().length;
    if (length < 3 || length > 200) {
      return context.l10n.barrierReasonInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('barrier_open_dialog'),
      title: Text(l10n.barrierOpenTitle(widget.barrier.name)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('barrier_reason'),
              controller: _controller,
              autofocus: true,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.barrierReasonLabel,
                hintText: l10n.barrierReasonHint,
              ),
              validator: _validate,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.barrierOpenConfirm,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('barrier_open_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.gateDismiss),
        ),
        FilledButton(
          key: const Key('barrier_open_confirm'),
          onPressed: _submit,
          child: Text(l10n.barrierOpen),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }
}
