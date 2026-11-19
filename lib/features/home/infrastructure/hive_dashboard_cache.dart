import 'dart:convert';

import '../../../core/lot/lot_session.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/entities/dashboard_snapshot.dart';
import '../domain/repositories/dashboard_cache.dart';

/// Stores the dashboard snapshot as JSON in the device `cache` box, keyed by
/// the active site so switching lots never shows another site's numbers.
class HiveDashboardCache implements DashboardCache {
  HiveDashboardCache(this._store, this._lots);

  final KeyValueStore _store;
  final LotSession _lots;

  static const _box = 'cache';

  String get _key => 'dashboard_${_lots.activeLotId ?? 0}';

  @override
  Future<DashboardSnapshot?> read() async {
    final raw = _store.get(_box, _key);
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return DashboardSnapshot.tryParse(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(DashboardSnapshot snapshot) =>
      _store.put(_box, _key, jsonEncode(snapshot.toJson()));
}
