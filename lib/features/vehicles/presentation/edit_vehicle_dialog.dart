import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dialog_header.dart';
import '../../../core/widgets/plate_text.dart';
import '../../categories/domain/entities/category.dart';
import '../domain/commands/update_vehicle_command.dart';
import '../domain/entities/vehicle.dart';

/// Admin editor for a vehicle's category, brand and color. The plate is the
/// identity used by tickets/history, so it stays read-only here.
class EditVehicleDialog extends StatefulWidget {
  const EditVehicleDialog({
    super.key,
    required this.existing,
    required this.categories,
    required this.onSave,
  });

  final Vehicle existing;
  final List<Category> categories;
  final void Function(UpdateVehicleCommand command) onSave;

  @override
  State<EditVehicleDialog> createState() => _EditVehicleDialogState();
}

class _EditVehicleDialogState extends State<EditVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: widget.existing.brand ?? '');
  late final _color = TextEditingController(text: widget.existing.color ?? '');
  late int? _categoryId = widget.existing.categoryId;

  @override
  void dispose() {
    _brand.dispose();
    _color.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    widget.onSave(
      UpdateVehicleCommand(
        id: widget.existing.id!,
        categoryId: _categoryId,
        brand: _brand.text.trim(),
        color: _color.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: DialogHeader(
        icon: Icons.edit_outlined,
        title: l10n.vehicleEditTitle,
        subtitle: l10n.vehicleEditHint,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car_outlined),
                      const SizedBox(width: Space.sm),
                      PlateText(widget.existing.plate),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              DropdownButtonFormField<int>(
                key: const Key('vehicle_edit_category'),
                initialValue: _categoryId,
                decoration: InputDecoration(labelText: l10n.fieldCategory),
                items: [
                  for (final category in widget.categories)
                    if (category.id != null)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) =>
                    value == null ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                key: const Key('vehicle_edit_brand'),
                controller: _brand,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.brandOptional),
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                key: const Key('vehicle_edit_color'),
                controller: _color,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.colorOptional),
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
        FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
