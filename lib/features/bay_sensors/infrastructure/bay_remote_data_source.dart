import '../../../core/network/supabase_error_mapper.dart';
import '../domain/commands/bay_commands.dart';
import '../domain/entities/bay_occupancy.dart';
import '../domain/entities/bay_sensor.dart';
import '../domain/repositories/bay_repository.dart';

typedef BayRpc = Future<dynamic> Function(
  String name,
  Map<String, dynamic> params,
);

abstract class BayRemoteDataSource {
  Future<BayOccupancy> occupancy();

  Future<List<BaySensor>> sensors();

  Future<BaySensor> mapSensor(MapBaySensor command);

  Future<void> unmapSensor(int sensorId);

  Future<BaySensor> setThreshold(SensorThresholdUpdate update);

  Future<void> dismissMismatch(int id, {String? note});

  Future<BaySensorSettings> settings();

  Future<BaySensorSettings> saveSettings(BaySensorSettings settings);
}

class SupabaseBayRemoteDataSource implements BayRemoteDataSource {
  SupabaseBayRemoteDataSource(this._rpc);

  final BayRpc _rpc;

  @override
  Future<BayOccupancy> occupancy() async {
    try {
      final data = await _rpc('bay_occupancy', {});
      return BayOccupancy.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<BaySensor>> sensors() async {
    try {
      final data = await _rpc('list_bay_sensors', {});
      return [
        for (final item in (data as List? ?? const []))
          if (item is Map) BaySensor.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<BaySensor> mapSensor(MapBaySensor command) async {
    try {
      await _rpc('map_bay_sensor', {
        'p_sensor_id': command.sensorId,
        'p_spot_id': command.spotId,
      });
      return _find(command.sensorId);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> unmapSensor(int sensorId) async {
    try {
      await _rpc('unmap_bay_sensor', {'p_sensor_id': sensorId});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<BaySensor> setThreshold(SensorThresholdUpdate update) async {
    try {
      await _rpc('set_bay_sensor_threshold', {
        'p_sensor_id': update.sensorId,
        'p_threshold': update.threshold,
        'p_hysteresis': update.hysteresis,
      });
      return _find(update.sensorId);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> dismissMismatch(int id, {String? note}) async {
    try {
      await _rpc('dismiss_bay_mismatch', {
        'p_mismatch_id': id,
        'p_note': note,
      });
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<BaySensorSettings> settings() async {
    try {
      final data = await _rpc('get_bay_sensor_settings', {});
      return BaySensorSettings.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<BaySensorSettings> saveSettings(BaySensorSettings settings) async {
    try {
      final data = await _rpc('set_bay_sensor_settings', settings.toRpc());
      return BaySensorSettings.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<BaySensor> _find(int sensorId) async {
    final all = await sensors();
    for (final sensor in all) {
      if (sensor.id == sensorId) return sensor;
    }
    throw const FormatException('sensor not found');
  }
}

class BayRepositoryImpl implements BayRepository {
  BayRepositoryImpl(this._remote);

  final BayRemoteDataSource _remote;

  @override
  Future<BayOccupancy> occupancy() => _remote.occupancy();

  @override
  Future<({List<BaySensor> mapped, List<BaySensor> unmapped})> sensors() async {
    final all = await _remote.sensors();
    return (
      mapped: [for (final sensor in all) if (sensor.mapped) sensor],
      unmapped: [for (final sensor in all) if (!sensor.mapped) sensor],
    );
  }

  @override
  Future<BaySensor> mapSensor(MapBaySensor command) =>
      _remote.mapSensor(command);

  @override
  Future<void> unmapSensor(int sensorId) => _remote.unmapSensor(sensorId);

  @override
  Future<BaySensor> setThreshold(SensorThresholdUpdate update) =>
      _remote.setThreshold(update);

  @override
  Future<void> dismissMismatch(int id, {String? note}) =>
      _remote.dismissMismatch(id, note: note);

  @override
  Future<BaySensorSettings> settings() => _remote.settings();

  @override
  Future<BaySensorSettings> saveSettings(BaySensorSettings settings) =>
      _remote.saveSettings(settings);
}
