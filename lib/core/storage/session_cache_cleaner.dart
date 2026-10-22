import 'package:hive_ce/hive_ce.dart';

import '../network/etag_cache_interceptor.dart';

/// Drops reference data cached for the previous user on logout.
///
/// The outbox is intentionally NOT cleared: queued work belongs to the device
/// and must still be replayed (a 403 is dead-lettered, not retried forever).
class SessionCacheCleaner {
  SessionCacheCleaner(this._etagCache);

  /// Hive boxes holding reference data. Branding/settings are deliberately
  /// kept: they belong to the parking lot, not to the signed-in user, and
  /// clearing them would blank the offline UI between shifts.
  static const cacheBoxNames = [
    'vehicles',
    'categories',
    'tariffs',
    'monthly_passes',
  ];

  final EtagCacheInterceptor _etagCache;

  Future<void> clear() async {
    _etagCache.clear();
    for (final name in cacheBoxNames) {
      await Hive.deleteBoxFromDisk(name);
    }
  }
}
