import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/evidence/domain/entities/session_evidence.dart';
import 'package:parking_management/features/evidence/infrastructure/session_evidence_remote_data_source.dart';
import 'package:parking_management/features/evidence/infrastructure/session_evidence_repository_impl.dart';

class _FakeRemote implements SessionEvidenceRemoteDataSource {
  _FakeRemote(this.items);

  final List<SessionEvidence> items;
  int? sessionId;

  @override
  Future<List<SessionEvidence>> listForSession(int sessionId) async {
    this.sessionId = sessionId;
    return items;
  }
}

void main() {
  test(
    'Success: the repository delegates to the remote for the session',
    () async {
      final items = [
        SessionEvidence(
          id: 1,
          path: 'abc/0.jpg',
          kind: EvidenceKind.photo,
          takenAt: DateTime(2026, 11, 9),
        ),
      ];
      final remote = _FakeRemote(items);
      final repository = SessionEvidenceRepositoryImpl(remote);

      final result = await repository.listForSession(12);

      expect(remote.sessionId, 12);
      expect(result, items);
    },
  );
}
