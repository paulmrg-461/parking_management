import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/tariffs/domain/commands/create_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/commands/update_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';
import 'package:parking_management/features/tariffs/domain/repositories/tariff_repository.dart';

const hourlyTariff = Tariff(
  id: 1,
  categoryId: 1,
  type: TariffType.hourly,
  amount: 3000,
);

class FakeTariffRepository implements TariffRepository {
  List<Tariff> tariffs = [hourlyTariff];
  Failure? listError;
  Failure? writeError;

  @override
  Future<List<Tariff>> list() async =>
      listError == null ? List.of(tariffs) : throw listError!;

  @override
  Future<Tariff> create(CreateTariffCommand command) async {
    if (writeError != null) {
      throw writeError!;
    }
    final tariff = Tariff(
      id: 2,
      categoryId: command.categoryId,
      type: command.type,
      amount: command.amount,
    );
    tariffs.add(tariff);
    return tariff;
  }

  final List<UpdateTariffCommand> updates = [];
  final List<int> deleted = [];

  @override
  Future<Tariff> update(UpdateTariffCommand command) async {
    if (writeError != null) {
      throw writeError!;
    }
    updates.add(command);
    return hourlyTariff;
  }

  @override
  Future<void> delete(int id) async {
    if (writeError != null) {
      throw writeError!;
    }
    deleted.add(id);
    tariffs.removeWhere((t) => t.id == id);
  }
}
