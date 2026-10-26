import 'package:hive_ce/hive_ce.dart';

import '../../../core/lot/lot_session.dart';
import '../domain/entities/monthly_pass.dart';

abstract class MonthlyPassLocalDataSource {
  Future<void> cacheAll(List<MonthlyPass> monthlyPasses);

  Future<List<MonthlyPass>> readAll();
}

/// Passes are lot-scoped, so the box key carries the lot (`<lotId>_<passId>`)
/// and reads only return the active lot's rows. This keeps the offline list
/// from mixing two sites without a schema change to the cached entity.
class HiveMonthlyPassLocalDataSource implements MonthlyPassLocalDataSource {
  HiveMonthlyPassLocalDataSource(this._lots);

  final LotSession _lots;

  static const _boxName = 'monthly_passes';

  Future<Box<MonthlyPass>> _box() => Hive.openBox<MonthlyPass>(_boxName);

  int get _lotId => _lots.activeLotId ?? 1;

  String _key(int lotId, int passId) => '${lotId}_$passId';

  @override
  Future<void> cacheAll(List<MonthlyPass> monthlyPasses) async {
    final box = await _box();
    final prefix = '${_lotId}_';
    for (final key in box.keys.toList()) {
      if ('$key'.startsWith(prefix)) {
        await box.delete(key);
      }
    }
    for (final monthlyPass in monthlyPasses) {
      final id = monthlyPass.id;
      if (id != null) {
        await box.put(_key(_lotId, id), monthlyPass);
      }
    }
  }

  @override
  Future<List<MonthlyPass>> readAll() async {
    final box = await _box();
    final prefix = '${_lotId}_';
    return [
      for (final key in box.keys)
        if ('$key'.startsWith(prefix)) box.get(key)!,
    ];
  }
}
