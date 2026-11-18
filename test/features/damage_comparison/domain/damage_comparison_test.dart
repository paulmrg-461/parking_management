import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/damage_comparison/domain/entities/damage_comparison.dart';

void main() {
  test('parses a completed comparison with findings', () {
    final view = DamageView.fromJson({
      'session_id': 1,
      'runs': 2,
      'stale': true,
      'comparison': {
        'id': 9,
        'run_number': 2,
        'status': 'completed',
        'overall': 'possible_new_damage',
        'summary': 'x',
        'entry_photo_count': 2,
        'exit_photo_count': 2,
        'findings': [
          {
            'id': 3, 'position': 1, 'zone': 'left', 'description': 'Rayón',
            'classification': 'new', 'confidence': 'high',
            'entry_photo_ids': [1], 'exit_photo_ids': [2],
            'review_status': 'confirmed',
          },
        ],
      },
    });
    expect(view.stale, isTrue);
    expect(view.comparison?.findings.single.classification,
        FindingClassification.newDamage);
    expect(view.comparison?.findings.single.reviewStatus,
        FindingReview.confirmed);
  });

  test('unknown enums fall back safely', () {
    final comparison = DamageComparison.fromJson(const {
      'id': 1,
      'status': 'bogus',
      'overall': 'bogus',
      'findings': [
        {'id': 1, 'zone': 'bogus', 'classification': 'bogus', 'review_status': 'bogus'},
      ],
    });
    expect(comparison.status, DamageStatus.pending);
    expect(comparison.overall, DamageOverall.insufficient);
    expect(comparison.findings.single.zone, DamageZone.other);
    expect(comparison.findings.single.classification,
        FindingClassification.uncertain);
    expect(comparison.findings.single.reviewStatus, FindingReview.open);
  });

  test('a null comparison is an empty view', () {
    final view = DamageView.fromJson(const {'session_id': 4, 'runs': 0});
    expect(view.comparison, isNull);
    expect(view.runs, 0);
  });
}
