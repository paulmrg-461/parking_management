import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/tariff.dart';

abstract class TariffLocalDataSource {
  Future<void> cacheAll(List<Tariff> tariffs);

  Future<List<Tariff>> readAll();

  Future<void> upsert(Tariff tariff);

  Future<void> remove(int id);
}

class HiveTariffLocalDataSource implements TariffLocalDataSource {
  static const _boxName = 'tariffs';

  /// Opens lazily on first use (returns the already-open box afterwards),
  /// so reads work on a cold start before any write happened.
  Future<Box<Tariff>> _box() => Hive.openBox<Tariff>(_boxName);

  @override
  Future<void> cacheAll(List<Tariff> tariffs) async {
    final box = await _box();
    await box.clear();
    for (final tariff in tariffs) {
      if (tariff.id != null) {
        await box.put(tariff.id, tariff);
      }
    }
  }

  @override
  Future<List<Tariff>> readAll() async {
    return (await _box()).values.toList();
  }

  @override
  Future<void> upsert(Tariff tariff) async {
    final id = tariff.id;
    if (id == null) {
      return;
    }
    final box = await _box();
    await box.put(id, tariff);
  }

  @override
  Future<void> remove(int id) async {
    final box = await _box();
    await box.delete(id);
  }
}
