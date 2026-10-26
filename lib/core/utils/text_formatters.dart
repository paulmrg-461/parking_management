import 'package:flutter/services.dart';

/// Uppercases plate input while the operator types: the server normalizes to
/// uppercase anyway, so seeing it live avoids surprises on the receipt.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
