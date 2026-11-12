import '../entities/session_evidence.dart';

/// In-app evidence of a session (lot-scoped by RLS). The URLs are signed for
/// a short window; a caller never stores them.
abstract class SessionEvidenceRepository {
  Future<List<SessionEvidence>> listForSession(int sessionId);
}
