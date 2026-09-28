import 'package:flutter/material.dart';

/// Semantic status colors not covered by [ColorScheme] (success, warning,
/// pending sync). Each foreground meets WCAG AA (≥ 4.5:1) against the theme
/// surface, and each `on*` against its status color (see
/// `status_colors_test.dart`).
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.pending,
    required this.onPending,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color pending;
  final Color onPending;

  static const light = StatusColors(
    success: Color(0xFF1B7F3B),
    onSuccess: Colors.white,
    warning: Color(0xFF8A5A00),
    onWarning: Colors.white,
    pending: Color(0xFF6B5B00),
    onPending: Colors.white,
  );

  static const dark = StatusColors(
    success: Color(0xFF6BD68A),
    onSuccess: Color(0xFF00391A),
    warning: Color(0xFFFFB951),
    onWarning: Color(0xFF462A00),
    pending: Color(0xFFE3C95A),
    onPending: Color(0xFF3A3000),
  );

  /// The extension registered on [context]'s theme (light as a fallback for
  /// bare `ThemeData()` in isolated tests).
  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  StatusColors copyWith() => this;

  @override
  StatusColors lerp(covariant StatusColors? other, double t) =>
      t < .5 ? this : (other ?? this);
}
