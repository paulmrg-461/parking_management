import 'package:flutter/material.dart';

abstract class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF1565C0),
      brightness: Brightness.light,
    );
  }
}
