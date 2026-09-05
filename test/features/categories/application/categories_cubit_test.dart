import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/categories/application/categories_cubit.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';

class _FakeRepository implements CategoryRepository {
  _FakeRepository({this.listError});

  final Failure? listError;

  @override
  Future<List<Category>> list() async {
    if (listError != null) {
      throw listError!;
    }
    return const [
      Category(id: 1, name: 'carro'),
      Category(id: 2, name: 'moto'),
    ];
  }

  @override
  Future<Category> create(String name) async => Category(id: 3, name: name);

  @override
  Future<Category> update(int id, String name) async =>
      Category(id: id, name: name);

  @override
  Future<void> delete(int id) async {}
}

void main() {
  test('load emits loaded state with categories', () async {
    final cubit = CategoriesCubit(_FakeRepository());

    await cubit.load();

    expect(cubit.state, isA<CategoriesLoaded>());
    expect((cubit.state as CategoriesLoaded).categories.length, 2);
  });

  test('load failure emits failure state', () async {
    final cubit = CategoriesCubit(
      _FakeRepository(listError: const NetworkFailure('offline')),
    );

    await cubit.load();

    expect(cubit.state, isA<CategoriesFailure>());
  });

  test('create persists and reloads the list', () async {
    final cubit = CategoriesCubit(_FakeRepository());

    await cubit.create('bus');

    expect(cubit.state, isA<CategoriesLoaded>());
  });
}
