import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'app_icon_button.dart';
import 'plate_text.dart';

/// Upper-cases and strips whitespace while typing, mirroring the domain's
/// `normalizePlate` so what the operator sees is what gets sent.
class PlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\s'), '').toUpperCase();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Licence-plate text field: large monospace text, normalization, required
/// validation, and a camera suffix when [onScan] is given (scanner
/// supported on this platform).
class PlateInputField extends StatelessWidget {
  const PlateInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onScan,
    this.autofocus = false,
    this.label,
  });

  /// Backend `max_length` for plates.
  static const maxLength = 20;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onScan;
  final bool autofocus;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      style: PlateText.styleFor(context, PlateSize.large),
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: [
        PlateInputFormatter(),
        LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(
        labelText: label ?? l10n.plateLabel,
        hintText: l10n.plateHint,
        suffixIcon: onScan == null
            ? null
            : AppIconButton(
                icon: Icons.photo_camera_outlined,
                tooltip: l10n.plateScanTooltip,
                onPressed: onScan,
              ),
      ),
      validator: (value) =>
          (value ?? '').trim().isEmpty ? l10n.errorEmptyPlate : null,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
    );
  }
}
