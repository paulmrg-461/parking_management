import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../categories/domain/entities/category.dart';

class ReservationDraft {
  const ReservationDraft({
    required this.plate,
    required this.categoryId,
    required this.until,
    this.notes,
  });

  final String plate;
  final int categoryId;
  final DateTime until;
  final String? notes;
}

/// Plate + category + hold window. Defaults to a two-hour hold from now.
class ReservationDialog extends StatefulWidget {
  const ReservationDialog({super.key, required this.categories});

  final List<Category> categories;

  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _notes = TextEditingController();
  int? _categoryId;
  late DateTime _until = DateTime.now().add(const Duration(hours: 2));

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.isEmpty ? null : widget.categories.first.id;
  }

  @override
  void dispose() {
    _plate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickUntil() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _until,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_until),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _until = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _save() {
    final categoryId = _categoryId;
    if (!_formKey.currentState!.validate() || categoryId == null) {
      return;
    }
    final notes = _notes.text.trim();
    Navigator.of(context).pop(
      ReservationDraft(
        plate: _plate.text.trim(),
        categoryId: categoryId,
        until: _until,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.reservationAdd),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _plate,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                decoration: InputDecoration(labelText: l10n.plateLabel),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.fieldRequired
                    : null,
              ),
              const SizedBox(height: Space.md),
              DropdownButtonFormField<int>(
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
              ),
              const SizedBox(height: Space.md),
              OutlinedButton.icon(
                onPressed: _pickUntil,
                icon: const Icon(Icons.schedule),
                label: Text(
                  l10n.reservationUntilLabel(
                    '${_until.day}/${_until.month} '
                    '${_until.hour.toString().padLeft(2, '0')}:'
                    '${_until.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _notes,
                decoration: InputDecoration(labelText: l10n.reservationNotes),
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
