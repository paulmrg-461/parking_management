import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_forecast.dart';

Map<String, dynamic> _payload({
  String status = 'ok',
  String? fullAt = '17:30',
  bool fullNow = false,
  int capacity = 40,
}) => {
  'lot_id': 1,
  'timezone': 'America/Bogota',
  'status': status,
  'horizon_hours': 2,
  'generated_at': '2026-11-04T19:20:00Z',
  'groups': [
    {
      'group': 'car',
      'capacity': capacity,
      'current': 31,
      'confidence': 'high',
      'samples': 8,
      'full_now': fullNow,
      'full_at': fullAt,
      'hours': [
        {'hour': 15, 'expected': 32, 'level': 'busy'},
        {'hour': 18, 'expected': 40, 'level': 'full'},
      ],
    },
  ],
};

void main() {
  test('Success: fromJson parses status, groups, hours and levels', () {
    final forecast = OccupancyForecast.fromJson(_payload());

    expect(forecast.status, ForecastStatus.ok);
    expect(forecast.hasForecast, isTrue);
    final group = forecast.groupOf('car')!;
    expect(group.capacity, 40);
    expect(group.current, 31);
    expect(group.confidence, ForecastConfidence.high);
    expect(group.hours.map((hour) => hour.level), [
      ForecastLevel.busy,
      ForecastLevel.full,
    ]);
    expect(group.peakExpected, 40);
  });

  test('Success: firstToFill returns fullNow before a later fullAt', () {
    final forecast = OccupancyForecast.fromJson(_payload(fullNow: true));

    expect(forecast.firstToFill?.fullNow, isTrue);
    expect(
      OccupancyForecast.fromJson(_payload()).firstToFill?.fullAt,
      '17:30',
    );
    expect(
      OccupancyForecast.fromJson(_payload(fullAt: null)).firstToFill,
      isNull,
    );
  });

  test('Failure: an unknown status becomes unavailable', () {
    final forecast = OccupancyForecast.fromJson(_payload(status: 'someday'));

    expect(forecast.status, ForecastStatus.unavailable);
    expect(forecast.hasForecast, isFalse);
    expect(forecast.firstToFill, isNull);
  });

  test('Failure: a malformed payload returns unavailable', () {
    expect(
      OccupancyForecast.fromJson(const <String, dynamic>{}).hasForecast,
      isFalse,
    );
  });

  test('Failure: non-map hour items are skipped', () {
    final forecast = OccupancyForecast.fromJson({
      'status': 'ok',
      'groups': [
        {
          'group': 'car',
          'hours': [1, 'x', {'hour': 7, 'expected': 3, 'level': 'free'}],
        },
      ],
    });

    expect(forecast.groupOf('car')?.hours.single.hour, 7);
  });
}
