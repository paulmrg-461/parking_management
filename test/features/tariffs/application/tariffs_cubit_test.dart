import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/tariffs/application/tariffs_cubit.dart';
import 'package:parking_management/features/tariffs/domain/commands/create_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/commands/update_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';
import 'package:parking_management/features/tariffs/domain/repositories/tariff_repository.dart';

class _FakeRepository implements TariffRepository {
  _FakeRepository({this.listError});

  final Failure? listError;

  @override
  Future<List<Tariff>> list() async {
    if (listError != null) {
      throw listError!;
    }
    return const [Tariff(id: 1, categoryId: 1, type: TariffType.hourly, amount: 3000)];
  }

  @override
  Future<Tariff> create(CreateTariffCommand command) async =>
      Tariff(id: 2, categoryId: command.categoryId, type: command.type, amount: command.amount);

  @override
  Future<Tariff> update(UpdateTariffCommand command) async =>
      const Tariff(id: 1, categoryId: 1, type: TariffType.daily, amount: 20000);

  @override
  Future<void> delete(int id) async {}
}

void main() {
  test('load emits loaded state with tariffs', () async {
    final cubit = TariffsCubit(_FakeRepository());

    await cubit.load();

    expect(cubit.state, isA<TariffsLoaded>());
    expect((cubit.state as TariffsLoaded).tariffs.single.amount, 3000);
  });

  test('load failure emits failure state', () async {
    final cubit = TariffsCubit(_FakeRepository(listError: const NetworkFailure('offline')));

    await cubit.load();

    expect(cubit.state, isA<TariffsFailure>());
  });

  test('create persists and reloads', () async {
    final cubit = TariffsCubit(_FakeRepository());

    await cubit.create(
      const CreateTariffCommand(categoryId: 1, type: TariffType.daily, amount: 20000),
    );

    expect(cubit.state, isA<TariffsLoaded>());
  });
}
