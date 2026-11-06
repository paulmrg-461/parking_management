import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_out/domain/entities/dashboard_trend.dart';

void main() {
  test('Success: parses the daily series oldest first', () {
    final trend = DashboardTrend.fromJson({
      'lot_id': 1,
      'start_date': '2026-11-03',
      'end_date': '2026-11-05',
      'days': [
        {'date': '2026-11-05', 'revenue': 5000, 'entries': 3, 'exits': 2},
        {'date': '2026-11-03', 'revenue': 0, 'entries': 0, 'exits': 0},
        {'date': '2026-11-04', 'revenue': 12000, 'entries': 5, 'exits': 4},
      ],
    });

    expect(trend.days, hasLength(3));
    expect(trend.days.first.date, DateTime(2026, 11, 3));
    expect(trend.days.last.date, DateTime(2026, 11, 5));
    expect(trend.totalRevenue, 17000);
    expect(trend.totalEntries, 8);
    expect(trend.totalExits, 6);
    expect(trend.peakRevenue, 12000);
    expect(trend.hasMovement, isTrue);
  });

  test('Failure: missing or malformed payloads degrade to an empty trend', () {
    expect(DashboardTrend.fromJson(const {}).isEmpty, isTrue);
    expect(DashboardTrend.fromJson(const {'days': 'nope'}).isEmpty, isTrue);
    expect(
      DashboardTrend.fromJson({
        'days': [
          {'date': 'not-a-date'},
          'garbage',
          {'revenue': 900},
        ],
      }).isEmpty,
      isFalse,
    );
  });

  test('Failure: unknown counters default to zero instead of throwing', () {
    final day = TrendDay.fromJson({'date': '2026-11-05', 'revenue': null});

    expect(day.revenue, 0);
    expect(day.entries, 0);
    expect(day.exits, 0);
    expect(day.hasMovement, isFalse);
  });

  test('Security: a quiet series is reported as no movement', () {
    final trend = DashboardTrend.fromJson({
      'days': [
        for (var day = 1; day <= 7; day++)
          {'date': '2026-11-0$day', 'revenue': 0, 'entries': 0, 'exits': 0},
      ],
    });

    expect(trend.isEmpty, isFalse);
    expect(trend.hasMovement, isFalse);
    expect(trend.peakRevenue, 0);
  });
}
