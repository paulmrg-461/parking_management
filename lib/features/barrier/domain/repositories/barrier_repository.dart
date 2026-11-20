import '../commands/barrier_config_update.dart';
import '../commands/open_barrier_request.dart';
import '../entities/barrier.dart';
import '../entities/barrier_command.dart';

abstract class BarrierRepository {
  Future<List<Barrier>> list();

  Future<BarrierCommand> openManually(OpenBarrierRequest request);

  Future<BarrierCommand> command(String id);

  Future<List<BarrierCommand>> history({int? deviceId});

  Future<Barrier> saveConfig(BarrierConfigUpdate update);
}
