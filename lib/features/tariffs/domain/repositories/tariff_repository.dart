import '../commands/create_tariff_command.dart';
import '../commands/update_tariff_command.dart';
import '../entities/tariff.dart';

abstract class TariffRepository {
  Future<List<Tariff>> list();

  Future<Tariff> create(CreateTariffCommand command);

  Future<Tariff> update(UpdateTariffCommand command);

  Future<void> delete(int id);
}
