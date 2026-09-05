import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/categories/application/categories_cubit.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';
import 'package:parking_management/features/tariffs/application/tariffs_cubit.dart';
import 'package:parking_management/features/tariffs/domain/commands/create_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/commands/update_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';
import 'package:parking_management/features/tariffs/domain/repositories/tariff_repository.dart';
import 'package:parking_management/features/tariffs/presentation/tariffs_page.dart';

class _FakeTariffRepository implements TariffRepository {
  @override
  Future<List<Tariff>> list() async =>
      const [Tariff(id: 1, categoryId: 1, type: TariffType.hourly, amount: 3000)];

  @override
  Future<Tariff> create(CreateTariffCommand command) async =>
      Tariff(id: 2, categoryId: command.categoryId, type: command.type, amount: command.amount);

  @override
  Future<Tariff> update(UpdateTariffCommand command) async =>
      const Tariff(id: 1, categoryId: 1, type: TariffType.hourly, amount: 3000);

  @override
  Future<void> delete(int id) async {}
}

class _FakeCategoryRepository implements CategoryRepository {
  @override
  Future<List<Category>> list() async => const [Category(id: 1, name: 'carro')];

  @override
  Future<Category> create(String name) async => Category(id: 2, name: name);

  @override
  Future<Category> update(int id, String name) async => Category(id: id, name: name);

  @override
  Future<void> delete(int id) async {}
}

void main() {
  testWidgets('renders tariffs with category names', (tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<TariffsCubit>(
            create: (_) => TariffsCubit(_FakeTariffRepository()),
          ),
          BlocProvider<CategoriesCubit>(
            create: (_) => CategoriesCubit(_FakeCategoryRepository()),
          ),
        ],
        child: const MaterialApp(home: TariffsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('carro · hourly'), findsOneWidget);
    expect(find.text('3000 COP'), findsOneWidget);
  });
}
