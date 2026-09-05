import '../../../core/error/failure.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/commands/create_vehicle_command.dart';
import '../domain/commands/update_vehicle_command.dart';
import '../domain/entities/vehicle.dart';
import '../domain/repositories/vehicle_repository.dart';
import 'vehicle_local_data_source.dart';
import 'vehicle_remote_data_source.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  VehicleRepositoryImpl(this._auth, this._remote, this._local);

  final AuthRepository _auth;
  final VehicleRemoteDataSource _remote;
  final VehicleLocalDataSource _local;

  @override
  Future<List<Vehicle>> list() async {
    final token = await _currentToken();
    try {
      final vehicles = await _remote.list(token);
      await _local.cacheAll(vehicles);
      return vehicles;
    } on NetworkFailure {
      return _local.readAll();
    }
  }

  @override
  Future<Vehicle?> findByPlate(String plate) async {
    final token = await _currentToken();
    try {
      final vehicles = await _remote.list(token, plate: plate);
      return vehicles.isNotEmpty ? vehicles.first : null;
    } on NetworkFailure {
      return _searchCache(plate);
    }
  }

  @override
  Future<Vehicle> create(CreateVehicleCommand command) async {
    return _remote.create(await _currentToken(), _toCreatePayload(command));
  }

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) async {
    return _remote.update(
      await _currentToken(),
      command.id,
      _toUpdatePayload(command),
    );
  }

  @override
  Future<void> delete(int id) async {
    await _remote.delete(await _currentToken(), id);
  }

  Future<Vehicle?> _searchCache(String plate) async {
    final normalized = _normalize(plate);
    for (final vehicle in await _local.readAll()) {
      if (vehicle.plate.toUpperCase() == normalized) {
        return vehicle;
      }
    }
    return null;
  }

  String _normalize(String plate) => plate.replaceAll(' ', '').toUpperCase();

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }

  Map<String, dynamic> _toCreatePayload(CreateVehicleCommand command) => {
        'plate': command.plate,
        'category_id': command.categoryId,
        'color': command.color,
        'brand': command.brand,
      };

  Map<String, dynamic> _toUpdatePayload(UpdateVehicleCommand command) => {
        if (command.categoryId != null) 'category_id': command.categoryId,
        if (command.color != null) 'color': command.color,
        if (command.brand != null) 'brand': command.brand,
      };
}
