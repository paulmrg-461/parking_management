import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';

/// In-memory [CategoryRepository] for cubit/page tests.
class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository([List<Category> categories = const []])
    : categories = List.of(categories);

  List<Category> categories;
  Failure? listError;
  Failure? writeError;

  @override
  Future<List<Category>> list() async =>
      listError == null ? List.of(categories) : throw listError!;

  @override
  Future<Category> create(String name) async {
    _throwIfWriteFails();
    final category = Category(id: categories.length + 100, name: name);
    categories.add(category);
    return category;
  }

  @override
  Future<Category> update(int id, String name) async {
    _throwIfWriteFails();
    final updated = Category(id: id, name: name);
    categories = [for (final c in categories) c.id == id ? updated : c];
    return updated;
  }

  @override
  Future<void> delete(int id) async {
    _throwIfWriteFails();
    categories.removeWhere((c) => c.id == id);
  }

  void _throwIfWriteFails() {
    if (writeError != null) {
      throw writeError!;
    }
  }
}
