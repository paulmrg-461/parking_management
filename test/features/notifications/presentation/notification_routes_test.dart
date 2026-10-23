import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/notifications/domain/entities/app_notification.dart';
import 'package:parking_management/features/notifications/presentation/notification_routes.dart';

AppNotification _n(String type, [Map<String, dynamic> data = const {}]) =>
    AppNotification(
      id: 1,
      type: type,
      title: 't',
      body: 'b',
      data: data,
      createdAt: DateTime.utc(2026),
    );

void main() {
  test('Success: shift and pass notifications open their screens', () {
    expect(routeForNotification(_n('shift_closed')), '/shift');
    expect(
      routeForNotification(_n('monthly_pass_renewed')),
      '/monthly-passes',
    );
  });

  test('Success: vehicle events open the history for the plate', () {
    expect(
      routeForNotification(_n('check_out', {'plate': 'ABC 123'})),
      '/history?plate=ABC+123',
    );
    expect(
      routeForNotification(_n('overstay', {'plate': 'XYZ999'})),
      '/history?plate=XYZ999',
    );
  });

  test('Security: unknown types never navigate', () {
    expect(routeForNotification(_n('unknown')), isNull);
    expect(routeForNotification(_n('check_in')), isNull);
  });
}
