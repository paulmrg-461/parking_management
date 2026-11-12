import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/lot/lot_session.dart';
import 'package:parking_management/features/home/infrastructure/hive_dashboard_cache.dart';

import '../../../helpers/dashboard_fixtures.dart';
import '../../../helpers/fake_key_value_store.dart';

void main() {
  test('Success: the snapshot round-trips per site', () async {
    final store = FakeKeyValueStore();
    final lots = LotSession()..select(1);
    final cache = HiveDashboardCache(store, lots);

    await cache.write(sampleDashboardSnapshot());
    final loaded = await cache.read();

    expect(loaded, isNotNull);
    expect(loaded!.occupancy.totalOpen, 3);
    expect(loaded.today.revenue, 25000);
    expect(loaded.trend.days, hasLength(2));
    expect(loaded.trend.days.last.revenue, 12000);
    expect(loaded.capacity.carTarget, 12);
    expect(loaded.capacity.reservationsExpiring, 1);
    expect(loaded.cachedAt, DateTime(2026, 11, 9, 14, 32));

    // Another site never reads the first one's numbers.
    lots.select(2);
    expect(await cache.read(), isNull);
    lots.select(1);
    expect((await cache.read())!.occupancy.totalOpen, 3);
  });

  test('Failure: malformed or unknown payloads are ignored', () async {
    final store = FakeKeyValueStore();
    final lots = LotSession()..select(1);
    final cache = HiveDashboardCache(store, lots);

    store.values['cache/dashboard_1'] = '{not json';
    expect(await cache.read(), isNull);

    store.values['cache/dashboard_1'] = jsonEncode({
      'version': 99,
      'cached_at': '2026-11-09T14:32:00.000',
      'occupancy': {'total_open': 1},
    });
    expect(await cache.read(), isNull);

    store.values['cache/dashboard_1'] = 42;
    expect(await cache.read(), isNull);
  });
}
