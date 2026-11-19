import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/lpr/domain/entities/lpr_event.dart';

Map<String, dynamic> payload({String status = 'pending', Object? reason = 'assist_mode'}) => {
  'id': 7,
  'kind': 'entry',
  'status': status,
  'reason': reason,
  'plate': 'ABC123',
  'confidence': 0.947,
  'votes': 3,
  'session_id': null,
  'has_pass': false,
  'snapshot_path': null,
  'device_name': 'Entrada',
  'created_at': '2026-11-10T14:03:21Z',
};

void main() {
  test('parses an event and its reason', () {
    final event = LprEvent.fromJson(payload());
    expect(event.plate, 'ABC123');
    expect(event.kind, LprEventKind.entry);
    expect(event.status, LprEventStatus.pending);
    expect(event.reason, LprEventReason.assistMode);
    expect(event.confidence, 0.947);
    expect(event.createdAt, DateTime.utc(2026, 11, 10, 14, 3, 21));
  });

  test('parses every exit reason', () {
    for (final entry in {
      'exit_unpaid': LprEventReason.exitUnpaid,
      'exit_paid': LprEventReason.exitPaid,
      'no_open_session': LprEventReason.noOpenSession,
      'blacklisted': LprEventReason.blacklisted,
    }.entries) {
      expect(
        LprEvent.fromJson(payload(reason: entry.key)).reason,
        entry.value,
      );
    }
  });

  test('an unknown reason is null instead of a crash', () {
    expect(LprEvent.fromJson(payload(reason: 'later_feature')).reason, isNull);
  });

  test('an unknown status is a format error', () {
    expect(
      () => LprEvent.fromJson(payload(status: 'archived')),
      throwsA(isA<FormatException>()),
    );
  });
}
