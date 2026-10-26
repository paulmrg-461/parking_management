import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import 'cop_formatter.dart';

/// Locale-aware display formatting (es_CO): `5/9/2026 14:07`, `$150.000`.
abstract final class Formatters {
  static String dateTime(DateTime value) =>
      DateFormat.yMd(formatLocale).add_Hm().format(value.toLocal());

  /// Receipt-style timestamp: `25/09/2026 14:07:05` (leading zeros + seconds).
  static String dateTimeFull(DateTime value) =>
      DateFormat('dd/MM/yyyy HH:mm:ss', formatLocale).format(value.toLocal());

  static String date(DateTime value) =>
      DateFormat.yMd(formatLocale).format(value.toLocal());

  static String time(DateTime value) =>
      DateFormat.Hm(formatLocale).format(value.toLocal());

  static String money(int amount) => CopFormatter.format(amount);

  /// `2 h 05 min` / `35 min`; negative durations clamp to zero.
  static String duration(AppLocalizations l10n, Duration value) {
    final minutes = value.isNegative ? 0 : value.inMinutes;
    final hours = minutes ~/ 60;
    return hours == 0
        ? l10n.durationMinutes(minutes)
        : l10n.durationHoursMinutes(hours, minutes % 60);
  }
}
