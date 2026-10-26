import 'package:hive_ce/hive_ce.dart';

import '../../../core/lot/lot_session.dart';
import '../domain/entities/category.dart';

abstract class CategoryLocalDataSource {
  Future<void> cacheAll(List<Category> categories);

  Future<List<Category>> readAll();

  Future<void> upsert(Category category);

  Future<void> remove(int id);
}

class HiveCategoryLocalDataSource implements CategoryLocalDataSource {
  HiveCategoryLocalDataSource(this._lots);

  final LotSession _lots;

  static const _boxName = 'categories';

  int get _lotId => _lots.activeLotId ?? 1;

  String _key(int id) => '${_lotId}_$id';

  /// Opens lazily on first use (returns the already-open box afterwards),
  /// so reads work on a cold start before any write happened.
  Future<Box<Category>> _box() => Hive.openBox<Category>(_boxName);

  @override
  Future<void> cacheAll(List<Category> categories) async {
    final box = await _box();
    final prefix = '${_lotId}_';
    for (final key in box.keys.toList()) {
      if ('$key'.startsWith(prefix)) {
        await box.delete(key);
      }
    }
    for (final category in categories) {
      final id = category.id;
      if (id != null) {
        await box.put(_key(id), category);
      }
    }
  }

  @override
  Future<List<Category>> readAll() async {
    final box = await _box();
    final prefix = '${_lotId}_';
    return [
      for (final key in box.keys)
        if ('$key'.startsWith(prefix)) box.get(key)!,
    ];
  }

  @override
  Future<void> upsert(Category category) async {
    final id = category.id;
    if (id == null) {
      return;
    }
    final box = await _box();
    await box.put(_key(id), category);
  }

  @override
  Future<void> remove(int id) async {
    final box = await _box();
    await box.delete(_key(id));
  }
}
