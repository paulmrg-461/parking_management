import 'package:flutter/material.dart';

/// Chart color tokens for the reports screen, per the project's `dataviz`
/// skill convention: a fixed-order categorical palette (validated for CVD
/// safety - `node validate_palette.js` worst adjacent CVD Delta-E 9.1 light /
/// 8.4 dark, both >= the 8 target) plus chart-chrome tokens (ink, muted axis,
/// gridline, surface), each with a light and dark step. Never hand-roll chart
/// colors outside this file.
class ReportColors {
  ReportColors._();

  /// Fixed-order categorical hues (never cycle/reassign by rank - a category
  /// keeps its slot for as long as it's on screen). Index 0 doubles as the
  /// single-series sequential hue for the revenue-by-day chart.
  static const List<Color> _categoricalLight = [
    Color(0xFF2A78D6), // blue
    Color(0xFFEB6834), // orange
    Color(0xFF1BAF7A), // aqua
    Color(0xFFEDA100), // yellow
    Color(0xFFE87BA4), // magenta
    Color(0xFF008300), // green
    Color(0xFF4A3AA7), // violet
    Color(0xFFE34948), // red
  ];

  static const List<Color> _categoricalDark = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
    Color(0xFF9085E9),
    Color(0xFFE66767),
  ];

  /// Categorical color for series/category [index], folding anything past
  /// the validated 8-slot ceiling onto the last ("Other") slot rather than
  /// generating a new hue.
  static Color categorical(BuildContext context, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? _categoricalDark : _categoricalLight;
    return palette[index.clamp(0, palette.length - 1)];
  }

  /// The single hue used for the revenue-by-day bars (one series -> no
  /// legend needed, per the skill's series-count ladder).
  static Color sequential(BuildContext context) => categorical(context, 0);

  static Color primaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF0B0B0B);

  static Color secondaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFC3C2B7)
          : const Color(0xFF52514E);

  static Color mutedText(BuildContext context) => const Color(0xFF898781);

  static Color gridline(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2C2C2A)
          : const Color(0xFFE1E0D9);

  static Color baseline(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF383835)
          : const Color(0xFFC3C2B7);

  static Color chartSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A19)
          : const Color(0xFFFCFCFB);
}
