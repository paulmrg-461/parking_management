import '../entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> list();

  Future<Category> create(String name);

  Future<Category> update(int id, String name);

  Future<Category> setCapacity(int id, int capacity);

  Future<void> delete(int id);
}
