import 'package:hive_ce/hive_ce.dart';

/// Drops reference data cached for the previous user on logout.
///
/// The outbox is intentionally NOT cleared: queued work belongs to the device
/// and must still be replayed (a 403 is dead-lettered, not retried forever).
class SessionCacheCleaner {
  const SessionCacheCleaner();

  /// Hive boxes holding reference data. Branding/settings are deliberately
  /// kept: they belong to the parking lot, not to the signed-in user.
  static const cacheBoxNames = [
    'vehicles',
    'categories',
    'tariffs',
    'monthly_passes',
    'notifications',
    'vehicle_history',
  ];

  Future<void> clear() async {
    for (final name in cacheBoxNames) {
      await Hive.deleteBoxFromDisk(name);
    }
  }
}
