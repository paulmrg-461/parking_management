import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reservations/domain/entities/reservation.dart';

Reservation _reservation(
  DateTime until, {
  int id = 1,
  String plate = 'ABC123',
}) => Reservation(id: id, plate: plate, categoryId: 2, reservedUntil: until);

void main() {
  final now = DateTime(2026, 10, 26, 12);

  test('Success: a hold inside the window expires soon', () {
    final hold = _reservation(now.add(const Duration(minutes: 30)));

    expect(hold.expiresSoon(now: now), isTrue);
    expect(hold.isExpiredAt(now), isFalse);
  });

  test('Failure: a distant hold is not expiring soon', () {
    final hold = _reservation(now.add(const Duration(hours: 5)));

    expect(hold.expiresSoon(now: now), isFalse);
    // The window is configurable for callers with a tighter policy.
    expect(hold.expiresSoon(now: now, window: const Duration(hours: 6)), isTrue);
  });

  test('Security: an expired hold is never reported as expiring soon', () {
    final hold = _reservation(now.subtract(const Duration(minutes: 1)));

    expect(hold.isExpiredAt(now), isTrue);
    expect(hold.expiresSoon(now: now), isFalse);
  });

  test('Success: sorting lists the soonest expiry first without mutating', () {
    final late = _reservation(now.add(const Duration(hours: 6)), id: 2);
    final soon = _reservation(now.add(const Duration(minutes: 10)), id: 1);
    final input = [late, soon];

    final sorted = sortedByExpiry(input);

    expect(sorted.map((r) => r.id), [1, 2]);
    expect(input.map((r) => r.id), [2, 1]);
  });
}
