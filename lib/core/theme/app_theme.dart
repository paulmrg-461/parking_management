import 'package:flutter/material.dart';

import 'status_colors.dart';
import 'tokens.dart';

/// Material 3 theme built from one seed, light and dark, with 48dp minimum
/// touch targets on every button family and outlined inputs.
abstract final class AppTheme {
  static const seed = Color(0xFF1565C0);

  static ThemeData light() => build(Brightness.light);

  static ThemeData dark() => build(Brightness.dark);

  static ThemeData build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [
        brightness == Brightness.light ? StatusColors.light : StatusColors.dark,
      ],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.md)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle()),
      textButtonTheme: TextButtonThemeData(style: _buttonStyle()),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(Layout.minTouch),
        ),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.md)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: Space.md),
        minTileHeight: Layout.minTouch,
      ),
    );
  }

  static ButtonStyle _buttonStyle() => const ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(64, Layout.minTouch)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.md)),
      ),
    ),
  );
}
