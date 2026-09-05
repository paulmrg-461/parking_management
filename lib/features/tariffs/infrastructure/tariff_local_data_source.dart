import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/tariff.dart';

abstract class TariffLocalDataSource {
  Future<void> cacheAll(List<Tariff> tariffs);

  Future<List<Tariff>> readAll();
}

class HiveTariffLocalDataSource implements TariffLocalDataSource {
  static const _boxName = 'tariffs';

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
    if (!Hive.isBoxOpen(_boxName)) {
      return const [];
    }
    return Hive.box<Tariff>(_boxName).values.toList();
  }
}
