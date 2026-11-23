import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/bay_sensors/domain/commands/bay_commands.dart';
import 'package:parking_management/features/bay_sensors/domain/entities/bay_sensor.dart';
import 'package:parking_management/features/bay_sensors/infrastructure/bay_remote_data_source.dart';

Map<String, dynamic> sensorJson(int id, {int? spotId = 10}) => {
  'sensor_id': id,
  'hub_device_id': 7,
  'hub_name': 'Hub',
  'channel': id,
  'spot_id': spotId,
  'spot_code': spotId == null ? null : 'A$id',
  'sensor_type': 'ultrasonic',
  'state': 'free',
  'health': 'ok',
  'threshold': 1800,
  'hysteresis': 150,
};

void main() {
  test('occupancy maps the payload', () async {
    final remote = SupabaseBayRemoteDataSource((name, params) async {
      expect(name, 'bay_occupancy');
      return {'sensors_enabled': true, 'bays': [], 'mismatches': []};
    });
    expect((await remote.occupancy()).sensorsEnabled, isTrue);
  });

  test('sensors are split into mapped and unmapped', () async {
    final repository = BayRepositoryImpl(
      SupabaseBayRemoteDataSource(
        (name, params) async => [sensorJson(1), sensorJson(2, spotId: null)],
      ),
    );
    final result = await repository.sensors();
    expect(result.mapped.single.id, 1);
    expect(result.unmapped.single.id, 2);
  });

  test('map calls the RPC and returns the refreshed sensor', () async {
    final calls = <String>[];
    final remote = SupabaseBayRemoteDataSource((name, params) async {
      calls.add(name);
      if (name == 'list_bay_sensors') return [sensorJson(1)];
      return {'sensor_id': 1, 'spot_id': 10, 'spot_code': 'A1'};
    });
    final sensor = await remote.mapSensor(
      const MapBaySensor(spotId: 10, sensorId: 1),
    );
    expect(sensor.spotCode, 'A1');
    expect(calls, ['map_bay_sensor', 'list_bay_sensors']);
  });

  test('unmap, threshold and dismiss send their params', () async {
    final seen = <String, Map<String, dynamic>>{};
    final remote = SupabaseBayRemoteDataSource((name, params) async {
      seen[name] = params;
      if (name == 'list_bay_sensors') return [sensorJson(1)];
      return {'threshold': 2000};
    });
    await remote.unmapSensor(1);
    await remote.setThreshold(
      const SensorThresholdUpdate(sensorId: 1, threshold: 2000),
    );
    await remote.dismissMismatch(4, note: 'ajuste');
    expect(seen['unmap_bay_sensor']?['p_sensor_id'], 1);
    expect(seen['set_bay_sensor_threshold']?['p_threshold'], 2000);
    expect(seen['dismiss_bay_mismatch']?['p_note'], 'ajuste');
  });

  test('settings roundtrip', () async {
    final remote = SupabaseBayRemoteDataSource((name, params) async {
      if (name == 'get_bay_sensor_settings') return {'debounce_seconds': 25};
      expect(params['p_debounce_seconds'], 30);
      return {'debounce_seconds': 30};
    });
    expect((await remote.settings()).debounceSeconds, 25);
    final saved = await remote.saveSettings(
      const BaySensorSettings(debounceSeconds: 30),
    );
    expect(saved.debounceSeconds, 30);
  });

  test('a typed error becomes a Failure', () {
    final remote = SupabaseBayRemoteDataSource(
      (name, params) async => throw Exception('SensorAlreadyMappedError'),
    );
    expect(() => remote.sensors(), throwsA(isA<Failure>()));
  });
}
