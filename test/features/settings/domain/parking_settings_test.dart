import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';

void main() {
  test('Success: the grace window defaults to 15 and reaches the payload', () {
    const settings = ParkingSettings();

    expect(settings.reservationGraceMinutes, 15);
    expect(settings.toPayload()['reservation_grace_minutes'], 15);
  });

  test('Success: copyWith keeps the grace window when it is not passed', () {
    const settings = ParkingSettings(reservationGraceMinutes: 30);

    expect(settings.copyWith(name: 'Otro').reservationGraceMinutes, 30);
    expect(
      settings.copyWith(reservationGraceMinutes: 0).reservationGraceMinutes,
      0,
    );
  });
}
