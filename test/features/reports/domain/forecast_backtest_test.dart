import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reports/domain/entities/forecast_backtest.dart';

void main() {
  test('Success: fromJson parses groups and leads', () {
    final backtest = ForecastBacktest.fromJson({
      'weeks': 4,
      'history_weeks': 8,
      'decay_pct': 85,
      'issue_hours': [8, 12, 16],
      'groups': [
        {
          'group': 'car',
          'points': 120,
          'mae': 1.25,
          'mae_prior_only': 2.5,
          'bias': -0.4,
          'by_lead': [
            {'lead_hours': 3, 'points': 40, 'mae': 0.54, 'mae_prior_only': 3.0},
          ],
        },
      ],
    });

    expect(backtest.hasData, isTrue);
    final group = backtest.groups.single;
    expect(group.mae, 1.25);
    expect(group.byLead.single.leadHours, 3);
    expect(group.isBetter, isTrue);
    expect(group.improvement, 50);
  });

  test('Failure: null mae parses as null', () {
    final backtest = ForecastBacktest.fromJson({
      'groups': [
        {'group': 'moto', 'points': 0, 'mae': null, 'mae_prior_only': null},
      ],
    });

    expect(backtest.groups.single.mae, isNull);
    expect(backtest.groups.single.isBetter, isFalse);
  });

  test('Failure: a malformed payload is empty', () {
    expect(ForecastBacktest.fromJson(const {}).hasData, isFalse);
    expect(ForecastBacktest.empty.hasData, isFalse);
  });
}
