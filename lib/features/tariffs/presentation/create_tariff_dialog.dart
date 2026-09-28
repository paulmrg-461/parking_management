import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../categories/domain/entities/category.dart';
import '../domain/commands/create_tariff_command.dart';
import '../domain/entities/tariff.dart';
import 'tariff_labels.dart';

final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// Validated tariff form: category, type, amount > 0 and, for nightly
/// tariffs, an HH:MM window.
class CreateTariffDialog extends StatefulWidget {
  const CreateTariffDialog({
    super.key,
    required this.categories,
    required this.onCreate,
  });

  final List<Category> categories;
  final void Function(CreateTariffCommand command) onCreate;

  @override
  State<CreateTariffDialog> createState() => _CreateTariffDialogState();
}

class _CreateTariffDialogState extends State<CreateTariffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  late int? _categoryId = widget.categories.firstOrNull?.id;
  TariffType _type = TariffType.hourly;

  bool get _nightly => _type == TariffType.nightly;

  @override
  void dispose() {
    _amountController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    widget.onCreate(
      CreateTariffCommand(
        categoryId: _categoryId!,
        type: _type,
        amount: int.parse(_amountController.text),
        startTime: _nightly ? _startController.text.trim() : null,
        endTime: _nightly ? _endController.text.trim() : null,
      ),
    );
    Navigator.of(context).pop();
  }

  String? _amount(String? value) {
    final amount = int.tryParse(value ?? '');
    return amount == null || amount <= 0 ? context.l10n.invalidAmount : null;
  }

  String? _time(String? value) =>
      _hhmm.hasMatch((value ?? '').trim()) ? null : context.l10n.invalidTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.tariffNew),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _categoryField(l10n),
              const SizedBox(height: Space.md),
              _typeField(l10n),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.fieldAmount),
                validator: _amount,
              ),
              if (_nightly) ..._windowFields(l10n),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionCreate)),
      ],
    );
  }

  List<Widget> _windowFields(AppLocalizations l10n) => [
    const SizedBox(height: Space.md),
    TextFormField(
      controller: _startController,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(labelText: l10n.tariffStart),
      validator: _time,
    ),
    const SizedBox(height: Space.md),
    TextFormField(
      controller: _endController,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(labelText: l10n.tariffEnd),
      validator: _time,
    ),
  ];

  Widget _categoryField(AppLocalizations l10n) => DropdownButtonFormField<int>(
    initialValue: _categoryId,
    items: [
      for (final category in widget.categories)
        if (category.id != null)
          DropdownMenuItem(value: category.id, child: Text(category.name)),
    ],
    onChanged: (value) => setState(() => _categoryId = value),
    decoration: InputDecoration(labelText: l10n.fieldCategory),
    validator: (value) => value == null ? l10n.fieldRequired : null,
  );

  Widget _typeField(AppLocalizations l10n) =>
      DropdownButtonFormField<TariffType>(
        initialValue: _type,
        items: [
          for (final type in TariffType.values)
            DropdownMenuItem(value: type, child: Text(type.label(l10n))),
        ],
        onChanged: (value) => setState(() => _type = value ?? _type),
        decoration: InputDecoration(labelText: l10n.fieldType),
      );
}
