/// Design tokens (8pt grid). Never hardcode spacing, radii or layout widths
/// in feature code: use these so the whole app keeps one visual rhythm.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

abstract final class Layout {
  /// Max width of page content (lists, dashboards).
  static const maxContent = 840.0;

  /// Max width of single-column forms (login, check-in).
  static const maxForm = 560.0;

  /// Width at which the shell switches NavigationBar → NavigationRail.
  static const railBreakpoint = 840.0;

  /// Minimum interactive size (Material / WCAG 2.5.5 target size).
  static const minTouch = 48.0;

  /// Evidence thumbnail edge.
  static const thumbnail = 96.0;
}

abstract final class Motion {
  static const short = Duration(milliseconds: 200);
}
