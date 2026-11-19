import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/pricing/domain/entities/fare_pricing.dart';
import 'package:parking_management/features/pricing/domain/entities/price_quote.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_rule.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_simulation.dart';

void main() {
  test('Success: parses a rule with a window', () {
    final rule = PricingRule.fromJson(const {
      'id': 7,
      'name': 'Noche valle',
      'priority': 100,
      'group': 'car',
      'from_time': '22:00',
      'to_time': '06:00',
      'multiplier_bps': 9000,
      'surcharge_amount': 0,
      'active': true,
    });

    expect(rule.fromMinute, 22 * 60);
    expect(rule.toMinute, 6 * 60);
    expect(rule.crossesMidnight, isTrue);
    expect(rule.hasMultiplier, isTrue);
    expect(rule.hasSurcharge, isFalse);
  });

  test('Success: weekdaySet reads the ISO bitmask', () {
    final rule = PricingRule.fromJson(const {
      'id': 1,
      'name': 'Finde',
      'weekdays': 96,
      'multiplier_bps': 12000,
    });

    expect(rule.weekdaySet, {6, 7});
  });

  test('Success: the draft sends p_ params', () {
    const draft = PricingRuleDraft(
      name: 'Alta',
      priority: 200,
      group: 'car',
      minOccupancyPct: 80,
      maxOccupancyPct: 100,
      weekdays: 32,
      fromMinute: 17 * 60,
      toMinute: 20 * 60,
      multiplierBps: 12000,
      surchargeAmount: 2000,
    );

    final params = draft.toParams();
    expect(params['p_name'], 'Alta');
    expect(params['p_from_time'], '17:00');
    expect(params['p_to_time'], '20:00');
    expect(params['p_multiplier_bps'], 12000);
    expect(params['p_surcharge_amount'], 2000);
  });

  test('Success: the quote parses its tier and rule', () {
    final quote = PriceQuote.fromJson(const {
      'enabled': true,
      'category_id': 3,
      'occupancy_pct': 85,
      'rule': {'id': 7, 'name': 'Alta ocupacion'},
      'multiplier_bps': 12000,
      'surcharge_amount': 0,
      'hourly_base': 3000,
      'hourly_current': 3600,
      'tier': 'higher',
    });

    expect(quote.isSurge, isTrue);
    expect(quote.ruleName, 'Alta ocupacion');
    expect(quote.hourlyCurrent, 3600);
  });

  test('Failure: an unknown tier falls back to base', () {
    final quote = PriceQuote.fromJson(const {'tier': 'peak'});
    expect(quote.tier, PriceTier.base);
  });

  test('Success: FarePricing maps the raw pricing object', () {
    final pricing = FarePricing.fromMap(const {
      'rule_id': 7,
      'rule_name': 'Alta ocupacion',
      'kind': 'multiplier',
      'multiplier_bps': 12000,
      'surcharge_amount': 0,
      'delta': 1800,
      'clamped': null,
      'locked_at': '2026-11-12T15:04:05Z',
      'source': 'checkin',
    });

    expect(pricing, isNotNull);
    expect(pricing!.percentDelta, 20);
    expect(pricing.delta, 1800);
    expect(FarePricing.fromMap(null), isNull);
  });

  test('Success: the simulation parses by rule and by hour', () {
    final simulation = PricingSimulation.fromJson(const {
      'days': 30,
      'sessions_considered': 10,
      'sessions_affected': 4,
      'base_total': 100000,
      'simulated_total': 112000,
      'delta': 12000,
      'delta_pct_bps': 1200,
      'at_floor': 1,
      'at_ceiling': 2,
      'by_rule': [
        {'rule_id': 7, 'name': 'Alta', 'sessions': 4, 'delta': 12000},
      ],
      'by_hour': [
        {'hour': 17, 'sessions': 4, 'delta': 12000},
      ],
    });

    expect(simulation.byRule.single.name, 'Alta');
    expect(simulation.byHour.single.hour, 17);
    expect(simulation.deltaPctBps, 1200);
    expect(simulation.isEmpty, isFalse);
  });

  test('Failure: a missing delta_pct_bps stays null', () {
    final simulation = PricingSimulation.fromJson(const {
      'days': 7,
      'sessions_considered': 0,
      'base_total': 0,
    });
    expect(simulation.deltaPctBps, isNull);
    expect(simulation.isEmpty, isTrue);
  });
}
