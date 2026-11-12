import '../domain/entities/session_evidence.dart';
import '../domain/repositories/session_evidence_repository.dart';
import 'session_evidence_remote_data_source.dart';

class SessionEvidenceRepositoryImpl implements SessionEvidenceRepository {
  SessionEvidenceRepositoryImpl(this._remote);

  final SessionEvidenceRemoteDataSource _remote;

  @override
  Future<List<SessionEvidence>> listForSession(int sessionId) =>
      _remote.listForSession(sessionId);
}
