import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/evidence/domain/entities/session_evidence.dart';

void main() {
  test('parses the exit phase', () {
    final evidence = SessionEvidence.fromJson(const {
      'id': 1,
      'file_path': 'exit/1.jpg',
      'kind': 'photo',
      'taken_at': '2026-11-18T10:00:00Z',
      'phase': 'exit',
    });
    expect(evidence.phase, EvidencePhase.exit);
  });

  test('missing or unknown phase defaults to entry', () {
    for (final phase in [null, 'bogus']) {
      final evidence = SessionEvidence.fromJson({
        'id': 1,
        'file_path': 'entry/1.jpg',
        'kind': 'photo',
        'phase': phase,
      });
      expect(evidence.phase, EvidencePhase.entry);
    }
  });
}
