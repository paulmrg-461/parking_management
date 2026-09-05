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
    if (!Hive.isBoxOpen(_boxName)) {
      return const [];
    }
    return Hive.box<Category>(_boxName).values.toList();
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
