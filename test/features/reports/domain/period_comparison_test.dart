import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reports/domain/entities/period_comparison.dart';

PeriodWindow _window({
  int days = 30,
  bool fullMonth = true,
  bool covered = true,
  int revenue = 0,
  int entries = 0,
  int exits = 0,
  int avgTicket = 0,
  int avgStay = 0,
  int passRevenue = 0,
  int reservations = 0,
  int reservationsUsed = 0,
}) => PeriodWindow(
  startDate: DateTime(2026, 9),
  endDate: DateTime(2026, 9),
  days: days,
  fullMonth: fullMonth,
  covered: covered,
  revenue: revenue,
  entries: entries,
  exits: exits,
  avgTicket: avgTicket,
  avgStayMinutes: avgStay,
  passRevenue: passRevenue,
  reservations: reservations,
  reservationsUsed: reservationsUsed,
);

Map<String, dynamic> _bucketJson(String month, int revenue) => {
  'month': month,
  'is_partial': false,
  'current': {
    'start_date': '$month-01',
    'end_date': '$month-28',
    'days': 28,
    'full_month': true,
    'covered': true,
    'revenue': revenue,
    'entries': 1,
    'exits': 1,
    'avg_ticket': revenue,
    'avg_stay_minutes': 60,
    'pass_revenue': 0,
    'reservations': 0,
    'reservations_used': 0,
  },
  'previous_month': {
    'start_date': '$month-01',
    'end_date': '$month-28',
    'days': 28,
    'full_month': true,
    'covered': true,
    'revenue': 0,
    'entries': 0,
    'exits': 0,
    'avg_ticket': 0,
    'avg_stay_minutes': 0,
    'pass_revenue': 0,
    'reservations': 0,
    'reservations_used': 0,
  },
  'previous_year': {
    'start_date': '$month-01',
    'end_date': '$month-28',
    'days': 28,
    'full_month': true,
    'covered': false,
    'revenue': 0,
    'entries': 0,
    'exits': 0,
    'avg_ticket': 0,
    'avg_stay_minutes': 0,
    'pass_revenue': 0,
    'reservations': 0,
    'reservations_used': 0,
  },
};

void main() {
  test('Success: fromJson parses buckets sorted oldest first', () {
    final report = PeriodComparison.fromJson({
      'months': 2,
      'timezone': 'America/Bogota',
      'as_of': '2026-10-31',
      'first_activity_date': '2026-03-14',
      'buckets': [_bucketJson('2026-10', 100), _bucketJson('2026-09', 50)],
    });

    expect(report.buckets.map((b) => b.monthKey), ['2026-09', '2026-10']);
    expect(report.latest?.monthKey, '2026-10');
    expect(report.hasData, isTrue);
    expect(report.asOf, DateTime(2026, 10, 31));
  });

  test('Success: valueOf maps every metric', () {
    final window = _window(
      revenue: 1,
      entries: 2,
      exits: 3,
      avgTicket: 4,
      avgStay: 5,
      passRevenue: 6,
      reservations: 7,
    );

    expect(window.valueOf(PeriodMetric.revenue), 1);
    expect(window.valueOf(PeriodMetric.entries), 2);
    expect(window.valueOf(PeriodMetric.exits), 3);
    expect(window.valueOf(PeriodMetric.avgTicket), 4);
    expect(window.valueOf(PeriodMetric.avgStay), 5);
    expect(window.valueOf(PeriodMetric.passRevenue), 6);
    expect(window.valueOf(PeriodMetric.reservations), 7);
  });

  test('Success: periodDelta rounds growth and decline', () {
    expect(
      periodDelta(
        _window(revenue: 12400000),
        _window(revenue: 11800000),
        PeriodMetric.revenue,
      ),
      5,
    );
    expect(
      periodDelta(
        _window(revenue: 3500000),
        _window(revenue: 4200000),
        PeriodMetric.revenue,
      ),
      -17,
    );
  });

  test('Success: periodDelta is zero when equal', () {
    expect(
      periodDelta(
        _window(revenue: 5000000),
        _window(revenue: 5000000),
        PeriodMetric.revenue,
      ),
      0,
    );
  });

  test('Failure: periodDelta is null on a zero base', () {
    expect(
      periodDelta(
        _window(revenue: 100),
        _window(revenue: 0),
        PeriodMetric.revenue,
      ),
      isNull,
    );
  });

  test('Failure: periodDelta is null when the base is not covered', () {
    expect(
      periodDelta(
        _window(revenue: 100),
        _window(revenue: 90, covered: false),
        PeriodMetric.revenue,
      ),
      isNull,
    );
  });

  test(
    'Failure: periodDelta is null on a shorter base that is not a full month',
    () {
      expect(
        periodDelta(
          _window(revenue: 100, days: 10, fullMonth: false),
          _window(revenue: 90, days: 31, fullMonth: false),
          PeriodMetric.revenue,
        ),
        isNull,
      );
      // A full base month is comparable even if the current window is partial.
      expect(
        periodDelta(
          _window(revenue: 100, days: 10, fullMonth: false),
          _window(revenue: 90, days: 28, fullMonth: true),
          PeriodMetric.revenue,
        ),
        11,
      );
    },
  );

  test('Failure: fromJson of a malformed payload returns empty', () {
    expect(
      PeriodComparison.fromJson({'buckets': 'nope'}),
      PeriodComparison.empty,
    );
  });

  test('Success: peakOf scales over current and previous year', () {
    final report = PeriodComparison.fromJson({
      'months': 1,
      'buckets': [
        {
          ..._bucketJson('2026-10', 100),
          'previous_year': {
            ..._bucketJson('2026-10', 0)['previous_year']
                as Map<String, dynamic>,
            'revenue': 300,
          },
        },
      ],
    });

    expect(report.peakOf(PeriodMetric.revenue), 300);
  });
}
