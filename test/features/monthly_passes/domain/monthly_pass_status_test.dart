import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';

MonthlyPass _pass(int id, DateTime start, DateTime end) => MonthlyPass(
  id: id,
  vehicleId: id,
  startDate: start,
  endDate: end,
  amount: 80000,
);

void main() {
  final now = DateTime(2026, 10, 26, 15);

  test('Success: status is derived from the calendar day', () {
    expect(
      monthlyPassStatus(
        _pass(1, DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
        now,
      ),
      MonthlyPassStatus.active,
    );
    expect(
      monthlyPassStatus(
        _pass(2, DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
        now,
      ),
      MonthlyPassStatus.upcoming,
    );
    expect(
      monthlyPassStatus(
        _pass(3, DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
        now,
      ),
      MonthlyPassStatus.expired,
    );
  });

  test('Success: active passes come first, then upcoming, then expired', () {
    final sorted = sortMonthlyPasses([
      _pass(1, DateTime(2026, 9, 1), DateTime(2026, 9, 30)), // expired
      _pass(2, DateTime(2026, 11, 1), DateTime(2026, 11, 30)), // upcoming
      _pass(3, DateTime(2026, 10, 1), DateTime(2026, 10, 20)), // expired
      _pass(4, DateTime(2026, 9, 1), DateTime(2026, 10, 31)), // active, later
    ], now: now);

    // Active (4), upcoming (2), then expired by most recent end (3, 1).
    expect(sorted.map((pass) => pass.id), [4, 2, 3, 1]);
  });

  test('Security: sorting never mutates the caller list', () {
    final original = [
      _pass(1, DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
      _pass(2, DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
    ];

    sortMonthlyPasses(original, now: now);

    expect(original.map((pass) => pass.id), [1, 2]);
  });
}
