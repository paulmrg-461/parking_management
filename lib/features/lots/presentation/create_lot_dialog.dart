import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';

class CreateLotDraft {
  const CreateLotDraft({
    required this.code,
    required this.name,
    required this.address,
  });

  final String code;
  final String name;
  final String address;
}

class CreateLotDialog extends StatefulWidget {
  const CreateLotDialog({super.key, required this.onCreate});

  final Future<void> Function(CreateLotDraft draft) onCreate;

  @override
  State<CreateLotDialog> createState() => _CreateLotDialogState();
}

class _CreateLotDialogState extends State<CreateLotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final draft = CreateLotDraft(
      code: _code.text.trim().toUpperCase(),
      name: _name.text.trim(),
      address: _address.text.trim(),
    );
    Navigator.of(context).pop();
    await widget.onCreate(draft);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.lotAdd),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(labelText: l10n.lotCode),
              validator: (value) => (value ?? '').trim().length < 2
                  ? l10n.fieldRequired
                  : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.lotName),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.lotAddress),
            ),
          ],
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
