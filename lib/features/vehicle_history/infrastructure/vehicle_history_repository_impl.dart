import '../../../core/error/failure.dart';
import '../domain/entities/vehicle_history.dart';
import '../domain/repositories/vehicle_history_repository.dart';
import 'vehicle_history_local_data_source.dart';
import 'vehicle_history_remote_data_source.dart';

class VehicleHistoryRepositoryImpl implements VehicleHistoryRepository {
  VehicleHistoryRepositoryImpl(this._remote, this._local);

  final VehicleHistoryRemoteDataSource _remote;
  final VehicleHistoryLocalDataSource _local;

  @override
  Future<VehicleHistory> lookup(String plate) async {
    try {
      final history = await _remote.lookup(plate);
      await _local.write(history);
      return history;
    } on NetworkFailure {
      final cached = await _local.read(plate);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<VehicleFlags> updateFlags(
    String plate, {
    bool? blacklisted,
    String? notes,
  }) => _remote.updateFlags(plate, blacklisted: blacklisted, notes: notes);
}
