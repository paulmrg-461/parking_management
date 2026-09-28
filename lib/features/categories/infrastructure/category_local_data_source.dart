import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/category.dart';

abstract class CategoryLocalDataSource {
  Future<void> cacheAll(List<Category> categories);

  Future<List<Category>> readAll();

  Future<void> upsert(Category category);

  Future<void> remove(int id);
}

class HiveCategoryLocalDataSource implements CategoryLocalDataSource {
  static const _boxName = 'categories';

  /// Opens lazily on first use (returns the already-open box afterwards),
  /// so reads work on a cold start before any write happened.
  Future<Box<Category>> _box() => Hive.openBox<Category>(_boxName);

  @override
  Future<void> cacheAll(List<Category> categories) async {
    final box = await _box();
    await box.clear();
    for (final category in categories) {
      if (category.id != null) {
        await box.put(category.id, category);
      }
    }
  }

  @override
  Future<List<Category>> readAll() async {
    return (await _box()).values.toList();
  }

  @override
  Future<void> upsert(Category category) async {
    final id = category.id;
    if (id == null) {
      return;
    }
    final box = await _box();
    await box.put(id, category);
  }

  @override
  Future<void> remove(int id) async {
    final box = await _box();
    await box.delete(id);
  }
}
