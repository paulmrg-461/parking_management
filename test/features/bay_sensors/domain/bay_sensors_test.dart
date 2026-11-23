import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/bay_sensors/domain/entities/bay_occupancy.dart';
import 'package:parking_management/features/bay_sensors/domain/entities/bay_sensor.dart';

void main() {
  test('parses the occupancy layer', () {
    final occupancy = BayOccupancy.fromJson({
      'sensors_enabled': true,
      'bays': [
        {
          'spot_id': 10,
          'code': 'A1',
          'state': 'occupied',
          'health': 'ok',
          'mismatch': 'occupied_unassigned',
        },
      ],
      'mismatches': [
        {
          'id': 4,
          'spot_id': 10,
          'code': 'A1',
          'kind': 'occupied_unassigned',
          'opened_at': '2026-11-23T10:00:00Z',
        },
      ],
    });
    expect(occupancy.sensorsEnabled, isTrue);
    expect(occupancy.of(10)?.state, BayState.occupied);
    expect(occupancy.of(10)?.mismatch, BayMismatchKind.occupiedUnassigned);
    expect(occupancy.mismatches.single.code, 'A1');
  });

  test('an unknown state is unknown and an unknown mismatch kind throws', () {
    expect(BayState.fromWire('later'), BayState.unknown);
    expect(
      () => BayOccupancy.fromJson({
        'sensors_enabled': true,
        'bays': [],
        'mismatches': [
          {'id': 1, 'spot_id': 1, 'code': 'A1', 'kind': 'new_kind'},
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('parses a sensor and its unit', () {
    final sensor = BaySensor.fromJson({
      'sensor_id': 3,
      'hub_device_id': 7,
      'hub_name': 'Hub',
      'channel': 2,
      'spot_id': 10,
      'spot_code': 'A1',
      'sensor_type': 'magnetic',
      'state': 'free',
      'health': 'stale',
      'threshold': 1800,
      'hysteresis': 150,
      'last_raw': 42.5,
      'flaps': 3,
    });
    expect(sensor.mapped, isTrue);
    expect(sensor.type, BaySensorType.magnetic);
    expect(sensor.type.unit, 'uT');
    expect(sensor.health, BayHealth.stale);
    expect(sensor.flapsLastHour, 3);
  });

  test('the settings payload uses the RPC parameter names', () {
    const settings = BaySensorSettings(debounceSeconds: 30, cooldownMinutes: 10);
    expect(settings.toRpc()['p_debounce_seconds'], 30);
    expect(settings.toRpc()['p_cooldown_minutes'], 10);
  });
}
