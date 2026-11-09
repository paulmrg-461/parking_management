import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/evidence/domain/entities/session_evidence.dart';
import 'package:parking_management/features/evidence/domain/repositories/session_evidence_repository.dart';

class FakeSessionEvidenceRepository implements SessionEvidenceRepository {
  FakeSessionEvidenceRepository([List<SessionEvidence> items = const []])
    : items = List.of(items);

  List<SessionEvidence> items;
  Failure? error;
  int calls = 0;

  @override
  Future<List<SessionEvidence>> listForSession(int sessionId) async {
    calls++;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return List.of(items);
  }
}
