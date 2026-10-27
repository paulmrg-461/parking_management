import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/entities/category.dart';

/// Edits a category's capacity (0 = unlimited).
class CapacityDialog extends StatefulWidget {
  const CapacityDialog({
    super.key,
    required this.category,
    required this.onSave,
  });

  final Category category;
  final void Function(int capacity) onSave;

  static Future<void> show(BuildContext context, CapacityDialog dialog) =>
      showDialog<void>(context: context, builder: (_) => dialog);

  @override
  State<CapacityDialog> createState() => _CapacityDialogState();
}

class _CapacityDialogState extends State<CapacityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(
    text: widget.category.capacity == 0
        ? ''
        : widget.category.capacity.toString(),
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
    widget.onSave(int.tryParse(_controller.text.trim()) ?? 0);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.categoryCapacityTitle(widget.category.name)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.categoryCapacityLabel,
            helperText: l10n.categoryCapacityUnlimited,
          ),
          validator: (value) {
            final capacity = int.tryParse((value ?? '').trim());
            if (capacity == null || capacity < 0) {
              return l10n.invalidAmount;
            }
            return null;
          },
          onFieldSubmitted: (_) => _save(),
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
