import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/categories/application/categories_cubit.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';
import 'package:parking_management/features/categories/presentation/categories_page.dart';

class _FakeRepository implements CategoryRepository {
  @override
  Future<List<Category>> list() async =>
      const [Category(id: 1, name: 'carro')];

  @override
  Future<Category> create(String name) async => Category(id: 2, name: name);

  @override
  Future<Category> update(int id, String name) async =>
      Category(id: id, name: name);

  @override
  Future<void> delete(int id) async {}
}

void main() {
  testWidgets('renders the list of categories after load', (tester) async {
    await tester.pumpWidget(
      BlocProvider<CategoriesCubit>(
        create: (_) => CategoriesCubit(_FakeRepository()),
        child: const MaterialApp(home: CategoriesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('carro'), findsOneWidget);
  });
}
