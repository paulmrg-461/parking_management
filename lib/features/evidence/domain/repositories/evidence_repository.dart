import '../entities/public_evidence.dart';

/// Reads the public evidence of a session; the plate is the access key.
abstract class EvidenceRepository {
  Future<PublicEvidence> fetch({
    required int sessionId,
    required String plate,
  });
}
