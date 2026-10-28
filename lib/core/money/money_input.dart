import 'package:flutter/services.dart';

/// Operators type money in major units (`5000` for COP, `50.00` for USD);
/// these formatters allow the decimal/thousands separators for both.
List<TextInputFormatter> moneyInputFormatters() => [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];
