import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/formatters.dart';

/// Tappable, validated date input opening the (localized) date picker.
class DateFormField extends FormField<DateTime> {
  DateFormField({
    super.key,
    required String label,
    super.initialValue,
    super.validator,
  }) : super(
         builder: (field) => _DateFieldBody(field: field, label: label),
       );
}

class _DateFieldBody extends StatelessWidget {
  const _DateFieldBody({required this.field, required this.label});

  final FormFieldState<DateTime> field;
  final String label;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: field.value ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      field.didChange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = field.value;
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: field.errorText,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value == null ? context.l10n.selectDate : Formatters.date(value),
        ),
      ),
    );
  }
}
