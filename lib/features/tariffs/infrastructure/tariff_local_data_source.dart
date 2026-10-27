import 'package:hive_ce/hive_ce.dart';

import '../../../core/lot/lot_session.dart';
import '../domain/entities/tariff.dart';

abstract class TariffLocalDataSource {
  Future<void> cacheAll(List<Tariff> tariffs);

  Future<List<Tariff>> readAll();

  Future<void> upsert(Tariff tariff);

  Future<void> remove(int id);
}

class HiveTariffLocalDataSource implements TariffLocalDataSource {
  HiveTariffLocalDataSource(this._lots);

  final LotSession _lots;

  static const _boxName = 'tariffs';

  int get _lotId => _lots.activeLotId ?? 1;

  String _key(int id) => '${_lotId}_$id';

  /// Opens lazily on first use (returns the already-open box afterwards),
  /// so reads work on a cold start before any write happened.
  Future<Box<Tariff>> _box() => Hive.openBox<Tariff>(_boxName);

  @override
  Future<void> cacheAll(List<Tariff> tariffs) async {
    final box = await _box();
    final prefix = '${_lotId}_';
    for (final key in box.keys.toList()) {
      if ('$key'.startsWith(prefix)) {
        await box.delete(key);
      }
    }
    for (final tariff in tariffs) {
      final id = tariff.id;
      if (id != null) {
        await box.put(_key(id), tariff);
      }
    }
  }

  @override
  Future<List<Tariff>> readAll() async {
    final box = await _box();
    final prefix = '${_lotId}_';
    return [
      for (final key in box.keys)
        if ('$key'.startsWith(prefix)) box.get(key)!,
    ];
  }

  @override
  Future<void> upsert(Tariff tariff) async {
    final id = tariff.id;
    if (id == null) {
      return;
    }
    final box = await _box();
    await box.put(_key(id), tariff);
  }

  @override
  Future<void> remove(int id) async {
    final box = await _box();
    await box.delete(_key(id));
  }
}
