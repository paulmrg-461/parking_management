import 'package:flutter/foundation.dart';

/// Remembers the session actions this device just performed, so the realtime
/// echo of our own write does not show a duplicate snackbar. The inbox still
/// keeps the row.
class LocalActivity {
  LocalActivity._();

  /// How long a local write may take to come back through Realtime.
  static const window = Duration(seconds: 30);

  static final Map<String, DateTime> _recent = {};

  static void remember(String action, int sessionId, {DateTime? at}) {
    final now = at ?? DateTime.now();
    _recent.removeWhere((_, when) => now.difference(when) > window);
    _recent['$action:$sessionId'] = now;
  }

  static bool owns(String action, int sessionId, {DateTime? now}) {
    final when = _recent['$action:$sessionId'];
    if (when == null) {
      return false;
    }
    return (now ?? DateTime.now()).difference(when) <= window;
  }

  @visibleForTesting
  static void clear() => _recent.clear();
}
