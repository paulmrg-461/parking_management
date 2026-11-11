import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/waitlist/domain/entities/public_waitlist.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_entry.dart';

Map<String, dynamic> _row({
  String status = 'waiting',
  int position = 2,
  String? offerUntil,
  int? reservationId,
}) => {
  'id': 11,
  'plate': 'ABC123',
  'category_id': 2,
  'category_name': 'car',
  'customer_name': 'Ana',
  'customer_phone': '3001112233',
  'status': status,
  'wait_until': '2026-01-01T15:00:00Z',
  'hold_minutes': 60,
  'offer_until': offerUntil,
  'reservation_id': reservationId,
  'position': position,
  'created_at': '2026-01-01T10:00:00Z',
};

void main() {
  test('Success: parses every status', () {
    for (final status in WaitlistStatus.values) {
      expect(
        WaitlistEntry.fromJson(_row(status: status.name)).status,
        status,
      );
    }
  });

  test('Failure: an unknown status falls back to expired', () {
    expect(
      WaitlistEntry.fromJson(_row(status: 'someday')).status,
      WaitlistStatus.expired,
    );
  });

  test('Success: contact line joins name and phone', () {
    expect(
      WaitlistEntry.fromJson(_row()).contactLine,
      'Ana · 3001112233',
    );
    expect(
      WaitlistEntry.fromJson(_row()..['customer_name'] = '').contactLine,
      '3001112233',
    );
  });

  test('Success: an offer knows its deadline and hold', () {
    final entry = WaitlistEntry.fromJson(
      _row(
        status: 'offered',
        offerUntil: '2026-01-01T16:00:00Z',
        reservationId: 77,
      ),
    );

    expect(entry.isOffered, isTrue);
    expect(entry.offerUntil, isNotNull);
    expect(entry.reservationId, 77);
    expect(entry.position, 2);
  });

  test('Success: the public info parses the per-category counts', () {
    final info = PublicWaitlistInfo.fromJson({
      'enabled': true,
      'claim_minutes': 20,
      'max_hold_minutes': 1440,
      'notify_channel': 'whatsapp',
      'waiting': [
        {'category_id': 2, 'count': 3},
        {'category_id': 4, 'count': 1},
      ],
    });

    expect(info.enabled, isTrue);
    expect(info.claimMinutes, 20);
    expect(info.notifyChannel, WaitlistChannel.whatsapp);
    expect(info.waitingFor(2), 3);
    expect(info.waitingFor(9), 0);
  });

  test('Success: the public entry parses offer and lot', () {
    final entry = PublicWaitlistEntry.fromJson({
      ..._row(
        status: 'offered',
        offerUntil: '2026-01-01T16:00:00Z',
        reservationId: 5,
      ),
      'claim_minutes': 15,
      'notify_channel': 'screen',
      'lot': {
        'id': 1,
        'name': 'Central',
        'address': 'Cra 7',
        'phone': '300',
        'whatsapp': '',
      },
    });

    expect(entry.isOffered, isTrue);
    expect(entry.lotName, 'Central');
    expect(entry.offerUntil, isNotNull);
    expect(entry.claimMinutes, 15);
  });

  test('Security: a finished turn is never offered again', () {
    for (final status in ['expired', 'left', 'cancelled']) {
      final entry = PublicWaitlistEntry.fromJson(_row(status: status));
      expect(entry.isFinished, isTrue);
      expect(entry.isOffered, isFalse);
    }
  });
}
