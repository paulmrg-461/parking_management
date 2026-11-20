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
  test('Success: lpr alerts open the gate inbox', () {
    for (final type in ['lpr_pending', 'lpr_exit', 'lpr_blacklisted']) {
      expect(routeForNotification(_n(type)), '/gate', reason: type);
    }
  });

  test('Success: barrier alerts open the barrier page', () {
    for (final type in [
      'barrier_manual_open',
      'barrier_command_failed',
      'barrier_fault',
    ]) {
      expect(routeForNotification(_n(type)), '/barrier', reason: type);
    }
  });

  test('Success: shift and pass notifications open their screens', () {
    expect(routeForNotification(_n('shift_closed')), '/shift');
    expect(routeForNotification(_n('monthly_pass_renewed')), '/monthly-passes');
  });

  test('Success: a paid renewal opens the passes screen', () {
    expect(routeForNotification(_n('pass_renewal_paid')), '/monthly-passes');
  });

  test('Success: online payment alerts open the plate history', () {
    expect(
      routeForNotification(_n('online_payment', {'plate': 'ABC123'})),
      '/history?plate=ABC123',
    );
    expect(
      routeForNotification(_n('online_payment_review', {'plate': 'ABC123'})),
      '/history?plate=ABC123',
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

  test('Success: a web booking opens the reservations board', () {
    expect(
      routeForNotification(
        _n('public_reservation', {'plate': 'WEB123', 'reservation_id': 7}),
      ),
      '/reservations',
    );
  });

  test('Success: fiscal alerts open the invoicing screen', () {
    expect(routeForNotification(_n('fiscal_document_failed')), '/invoicing');
    expect(routeForNotification(_n('fiscal_resolution_low')), '/invoicing');
  });

  test('Security: unknown types never navigate', () {
    expect(routeForNotification(_n('unknown')), isNull);
    expect(routeForNotification(_n('check_in')), isNull);
  });

  test('Success: waitlist events open the reservations board', () {
    expect(routeForNotification(_n('waitlist_joined')), '/reservations');
    expect(routeForNotification(_n('waitlist_offer')), '/reservations');
  });

  test('Success: cash_anomaly routes to /anomalies', () {
    expect(routeForNotification(_n('cash_anomaly')), '/anomalies');
  });
}
