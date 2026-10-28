import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/evidence/domain/entities/public_evidence.dart';
import 'package:parking_management/features/evidence/domain/repositories/evidence_repository.dart';

class FakeEvidenceRepository implements EvidenceRepository {
  FakeEvidenceRepository({this.evidence, this.error});

  PublicEvidence? evidence;
  Failure? error;
  int calls = 0;
  int? lastSession;
  String? lastPlate;

  @override
  Future<PublicEvidence> fetch({
    required int sessionId,
    required String plate,
  }) async {
    calls++;
    lastSession = sessionId;
    lastPlate = plate;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return evidence ??
        PublicEvidence(plate: plate, entryTime: DateTime(2026, 10, 28, 8));
  }
}
