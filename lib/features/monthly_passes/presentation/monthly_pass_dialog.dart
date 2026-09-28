import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/date_form_field.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../domain/entities/monthly_pass.dart';

/// What the form produced; [vehicleId] is `null` when editing.
class MonthlyPassDraft {
  const MonthlyPassDraft({
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.amount,
  });

  final int? vehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final int amount;
}

/// Create (with vehicle picker) or edit ([existing]) a monthly pass;
/// validates dates (end after start) and a positive amount.
class MonthlyPassDialog extends StatefulWidget {
  const MonthlyPassDialog({
    super.key,
    required this.onSave,
    this.vehicles = const [],
    this.existing,
  });

  final List<Vehicle> vehicles;
  final MonthlyPass? existing;
  final void Function(MonthlyPassDraft draft) onSave;

  @override
  State<MonthlyPassDialog> createState() => _MonthlyPassDialogState();
}

class _MonthlyPassDialogState extends State<MonthlyPassDialog> {
  final _formKey = GlobalKey<FormState>();
  final _startKey = GlobalKey<FormFieldState<DateTime>>();
  final _endKey = GlobalKey<FormFieldState<DateTime>>();
  late final _amountController = TextEditingController(
    text: widget.existing?.amount.toString() ?? '',
  );
  late int? _vehicleId = widget.vehicles.firstOrNull?.id;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _required(Object? value) =>
      value == null ? context.l10n.fieldRequired : null;

  String? _endDate(DateTime? value) {
    final start = _startKey.currentState?.value;
    if (value == null) {
      return context.l10n.fieldRequired;
    }
    return start != null && !value.isAfter(start)
        ? context.l10n.dateRangeInvalid
        : null;
  }

  String? _amount(String? value) {
    final amount = int.tryParse(value ?? '');
    return amount == null || amount <= 0 ? context.l10n.invalidAmount : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    widget.onSave(
      MonthlyPassDraft(
        vehicleId: _editing ? null : _vehicleId,
        startDate: _startKey.currentState!.value!,
        endDate: _endKey.currentState!.value!,
        amount: int.parse(_amountController.text),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(_editing ? l10n.monthlyPassEdit : l10n.monthlyPassNew),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_editing) ...[
                _vehicleField(l10n),
                const SizedBox(height: Space.md),
              ],
              DateFormField(
                key: _startKey,
                label: l10n.fieldStartDate,
                initialValue: widget.existing?.startDate,
                validator: _required,
              ),
              const SizedBox(height: Space.md),
              DateFormField(
                key: _endKey,
                label: l10n.fieldEndDate,
                initialValue: widget.existing?.endDate,
                validator: _endDate,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.fieldAmount),
                validator: _amount,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_editing ? l10n.actionSave : l10n.actionCreate),
        ),
      ],
    );
  }

  Widget _vehicleField(AppLocalizations l10n) => DropdownButtonFormField<int>(
    initialValue: _vehicleId,
    items: [
      for (final vehicle in widget.vehicles)
        if (vehicle.id != null)
          DropdownMenuItem(value: vehicle.id, child: Text(vehicle.plate)),
    ],
    onChanged: (value) => setState(() => _vehicleId = value),
    decoration: InputDecoration(labelText: l10n.fieldVehicle),
    validator: _required,
  );
}
