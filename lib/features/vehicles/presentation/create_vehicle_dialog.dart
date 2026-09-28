import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/plate_input_field.dart';
import '../../categories/domain/entities/category.dart';
import '../domain/commands/create_vehicle_command.dart';

/// Validated "new vehicle" form: plate and category are required.
class CreateVehicleDialog extends StatefulWidget {
  const CreateVehicleDialog({
    super.key,
    required this.categories,
    required this.onCreate,
  });

  final List<Category> categories;
  final void Function(CreateVehicleCommand command) onCreate;

  @override
  State<CreateVehicleDialog> createState() => _CreateVehicleDialogState();
}

class _CreateVehicleDialogState extends State<CreateVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();
  final _brandController = TextEditingController();
  late int? _categoryId = widget.categories.firstOrNull?.id;

  @override
  void dispose() {
    _plateController.dispose();
    _colorController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    widget.onCreate(
      CreateVehicleCommand(
        plate: _plateController.text.trim(),
        categoryId: _categoryId!,
        color: _optional(_colorController),
        brand: _optional(_brandController),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.vehicleNew),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlateInputField(controller: _plateController, autofocus: true),
              const SizedBox(height: Space.md),
              _categoryField(l10n),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _brandController,
                decoration: InputDecoration(labelText: l10n.brandOptional),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _colorController,
                decoration: InputDecoration(labelText: l10n.colorOptional),
                textCapitalization: TextCapitalization.words,
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
        FilledButton(onPressed: _submit, child: Text(l10n.actionCreate)),
      ],
    );
  }

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
}
