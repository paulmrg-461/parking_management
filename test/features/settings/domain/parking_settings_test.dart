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

  test('Success: pass renewal defaults off with the 7,3,1 cadence', () {
    const settings = ParkingSettings();

    expect(settings.passRenewalEnabled, isFalse);
    expect(settings.passRenewalPaymentLinks, isFalse);
    expect(settings.passRenewalCadence, '7,3,1');
    expect(settings.toPayload()['pass_renewal_cadence'], '7,3,1');
  });

  test('Success: copyWith keeps the renewal switches', () {
    const settings = ParkingSettings(
      passRenewalEnabled: true,
      passRenewalCadence: '10,5',
    );

    final updated = settings.copyWith(name: 'Otro');
    expect(updated.passRenewalEnabled, isTrue);
    expect(updated.passRenewalCadence, '10,5');
    expect(
      settings.copyWith(passRenewalPaymentLinks: true).passRenewalPaymentLinks,
      isTrue,
    );
  });
}
