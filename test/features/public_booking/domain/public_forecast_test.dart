import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_forecast.dart';
import 'package:parking_management/features/public_booking/domain/entities/public_booking.dart';

void main() {
  test('Success: fromJson parses status, groups and levels', () {
    final forecast = PublicForecast.fromJson({
      'status': 'ok',
      'timezone': 'America/Bogota',
      'groups': [
        {
          'group': 'car',
          'confidence': 'high',
          'full_now': false,
          'full_at': '17:30',
          'hours': [
            {'hour': 15, 'level': 'busy'},
            {'hour': 18, 'level': 'full'},
          ],
        },
      ],
    });

    expect(forecast.isVisible, isTrue);
    expect(forecast.groups.single.fullAt, '17:30');
    expect(forecast.groups.single.hours.map((hour) => hour.level), [
      ForecastLevel.busy,
      ForecastLevel.full,
    ]);
  });

  test('Failure: missing forecast key is hidden', () {
    final availability = PublicBookingAvailability.fromJson({
      'lot': {'id': 1, 'name': 'Central'},
      'categories': [],
    });

    expect(availability.forecast.isVisible, isFalse);
  });

  test('Failure: unknown status is hidden', () {
    final forecast = PublicForecast.fromJson({
      'status': 'someday',
      'groups': [],
    });

    expect(forecast.isVisible, isFalse);
  });

  test('Security: hidden and empty groups are not visible', () {
    expect(
      PublicForecast.fromJson({'status': 'hidden', 'groups': []}).isVisible,
      isFalse,
    );
    expect(
      PublicForecast.fromJson({'status': 'ok', 'groups': []}).isVisible,
      isFalse,
    );
  });
}
