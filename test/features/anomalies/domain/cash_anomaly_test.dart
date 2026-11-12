import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/anomalies/domain/entities/anomaly_settings.dart';
import 'package:parking_management/features/anomalies/domain/entities/cash_anomaly.dart';

void main() {
  test('Success: fromJson parses every rule, severity and status', () {
    for (final rule in AnomalyRule.values) {
      final parsed = CashAnomaly.fromJson({
        'id': 1,
        'rule': rule.wire,
        'severity': 'high',
        'status': 'open',
        'detected_at': '2026-11-10T14:05:00Z',
        'details': {'plate': 'ABC123'},
      });
      expect(parsed.rule, rule);
      expect(parsed.severity, AnomalySeverity.high);
      expect(parsed.status, AnomalyStatus.open);
      expect(parsed.isOpen, isTrue);
    }
    for (final severity in AnomalySeverity.values) {
      expect(
        CashAnomaly.fromJson({'severity': severity.wire}).severity,
        severity,
      );
    }
    expect(
      CashAnomaly.fromJson({'status': 'dismissed'}).status,
      AnomalyStatus.dismissed,
    );
  });

  test('Success: AnomalyList.fromJson reads open_count', () {
    final list = AnomalyList.fromJson({
      'open_count': 4,
      'items': [
        {'id': 2, 'rule': 'zero_charge', 'severity': 'medium'},
      ],
    });

    expect(list.openCount, 4);
    expect(list.items.single.id, 2);
  });

  test('Failure: an unknown rule name is skipped, not thrown', () {
    final list = AnomalyList.fromJson({
      'items': [
        {'id': 3}, // no rule: falls back to a known rule, never crashes
        {'id': 4, 'rule': 'zero_charge'},
      ],
    });

    expect(list.items, hasLength(2));
  });

  test('Failure: malformed payload returns AnomalyList.empty', () {
    expect(AnomalyList.fromJson(const {}).items, isEmpty);
    expect(AnomalyList.fromJson(const {'items': 'nope'}).openCount, 0);
  });

  test('Success: AnomalySettings toJson only carries accepted keys', () {
    final json = AnomalySettings.defaults.toJson();

    expect(json['window_days'], 14);
    expect(json['shortage_min_amount'], 5000);
    expect(json['disabled_rules'], isEmpty);
    expect(json.containsKey('id'), isFalse);
    expect(json.containsKey('lot_id'), isFalse);
    expect(json.length, 14);
  });

  test('Success: AnomalySettings defaults match the SQL defaults', () {
    const defaults = AnomalySettings.defaults;

    expect(defaults.enabled, isTrue);
    expect(defaults.windowDays, 14);
    expect(defaults.shortageMinShifts, 3);
    expect(defaults.lostTicketMinClosed, 10);
    expect(defaults.lostTicketMinRatePct, 10);
    expect(defaults.lostTicketFactorPct, 200);
    expect(defaults.adjustmentMinAmount, 1000);
    expect(defaults.shortStayMinutes, 30);
    expect(defaults.discountMinCount, 3);
    expect(defaults.discountSharePct, 10);
    expect(defaults.shiftOpenHours, 16);
    expect(defaults.sessionOpenDays, 7);
  });
}
