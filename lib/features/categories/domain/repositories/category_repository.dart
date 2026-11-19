import '../entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> list();

  Future<Category> create(String name);

  Future<Category> update(int id, String name, {int? baseVersion});

  Future<Category> setCapacity(int id, int capacity, {int? baseVersion});

  Future<void> delete(int id, {int? baseVersion});
}
