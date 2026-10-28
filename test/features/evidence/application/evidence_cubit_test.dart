import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/evidence/application/evidence_cubit.dart';
import 'package:parking_management/features/evidence/domain/entities/public_evidence.dart';

import '../../../helpers/fake_evidence_repository.dart';

void main() {
  test('Success: loads the session evidence with the plate key', () async {
    final repository = FakeEvidenceRepository(
      evidence: PublicEvidence(
        plate: 'ABC123',
        entryTime: DateTime(2026, 10, 28, 8),
        photos: [
          EvidenceMedia(url: 'https://x/1.jpg', takenAt: DateTime(2026)),
        ],
      ),
    );
    final cubit = EvidenceCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(sessionId: 43, plate: 'abc123');

    expect(cubit.state.status, EvidenceStatus.loaded);
    expect(cubit.state.evidence?.plate, 'ABC123');
    expect(repository.lastSession, 43);
    expect(repository.lastPlate, 'abc123');
  });

  test('Failure: an invalid link never calls the server', () async {
    final repository = FakeEvidenceRepository();
    final cubit = EvidenceCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(sessionId: null, plate: null);
    expect(cubit.state.status, EvidenceStatus.failure);
    expect(repository.calls, 0);

    await cubit.load(sessionId: 0, plate: 'ABC123');
    expect(repository.calls, 0);
  });

  test('Security: a wrong plate surfaces the failure state', () async {
    final repository = FakeEvidenceRepository(
      error: const ValidationFailure('nope', 'EvidenceNotFoundError'),
    );
    final cubit = EvidenceCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(sessionId: 43, plate: 'ZZZ999');

    expect(cubit.state.status, EvidenceStatus.failure);
    expect(cubit.state.failure?.code, 'EvidenceNotFoundError');
  });
}
