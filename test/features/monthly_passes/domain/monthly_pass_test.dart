import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';

MonthlyPass _pass({DateTime? start, DateTime? end}) => MonthlyPass(
  id: 1,
  vehicleId: 1,
  startDate: start ?? DateTime(2026, 1, 1),
  endDate: end ?? DateTime(2026, 1, 31),
  amount: 100000,
);

void main() {
  test('Success: a pass ending within the week needs renewal', () {
    final pass = _pass();

    expect(pass.needsRenewal(now: DateTime(2026, 1, 20)), isFalse);
    expect(pass.needsRenewal(now: DateTime(2026, 1, 25)), isTrue);
    expect(pass.needsRenewal(now: DateTime(2026, 2, 2)), isTrue);
  });

  test('Failure: a long-running pass is not offered a renewal', () {
    expect(_pass().needsRenewal(now: DateTime(2026, 1, 2)), isFalse);
  });

  test('Success: renewal starts the day after the current end', () {
    final period = _pass().renewedPeriod(now: DateTime(2026, 1, 20));

    expect(period.start, DateTime(2026, 2, 1));
    expect(period.end, DateTime(2026, 3, 2));
  });

  test('Security: an expired pass renews from today, never in the past', () {
    final period = _pass().renewedPeriod(now: DateTime(2026, 2, 10));

    expect(period.start, DateTime(2026, 2, 10));
    expect(period.end.difference(period.start).inDays, 29);
  });
}
