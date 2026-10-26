import '../l10n/l10n.dart';
import 'formatters.dart';

/// Compact "how long has this been open" label (`2 h 05 min`), clamped to zero
/// when the device clock is behind the server.
String elapsedLabel(
  AppLocalizations l10n,
  DateTime since, {
  DateTime? now,
}) => Formatters.duration(l10n, (now ?? DateTime.now()).difference(since));

/// Sessions open beyond the parking lot's usual day are worth flagging.
bool isLongStay(
  DateTime since, {
  DateTime? now,
  Duration threshold = const Duration(hours: 24),
}) => (now ?? DateTime.now()).difference(since) >= threshold;
