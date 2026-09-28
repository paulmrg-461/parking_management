import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';

/// Single required-name form (create / rename). Enter submits.
class NameDialog extends StatefulWidget {
  const NameDialog({
    super.key,
    required this.title,
    required this.onSave,
    this.initial = '',
  });

  final String title;
  final String initial;
  final void Function(String name) onSave;

  static Future<void> show(BuildContext context, NameDialog dialog) =>
      showDialog<void>(context: context, builder: (_) => dialog);

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    widget.onSave(_controller.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: InputDecoration(labelText: l10n.fieldName),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _save(),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? l10n.fieldRequired : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
