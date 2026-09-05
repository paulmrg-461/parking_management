import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/monthly_pass.dart';

abstract class MonthlyPassLocalDataSource {
  Future<void> cacheAll(List<MonthlyPass> monthlyPasses);

  Future<List<MonthlyPass>> readAll();
}

class HiveMonthlyPassLocalDataSource implements MonthlyPassLocalDataSource {
  static const _boxName = 'monthly_passes';

  Future<Box<MonthlyPass>> _box() => Hive.openBox<MonthlyPass>(_boxName);

  @override
  Future<void> cacheAll(List<MonthlyPass> monthlyPasses) async {
    final box = await _box();
    await box.clear();
    for (final monthlyPass in monthlyPasses) {
      if (monthlyPass.id != null) {
        await box.put(monthlyPass.id, monthlyPass);
      }
    }
  }

  @override
  Future<List<MonthlyPass>> readAll() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return const [];
    }
    return Hive.box<MonthlyPass>(_boxName).values.toList();
  }
}
