import '../domain/entities/public_evidence.dart';
import '../domain/repositories/evidence_repository.dart';
import 'evidence_remote_data_source.dart';

class EvidenceRepositoryImpl implements EvidenceRepository {
  EvidenceRepositoryImpl(this._remote);

  final EvidenceRemoteDataSource _remote;

  @override
  Future<PublicEvidence> fetch({
    required int sessionId,
    required String plate,
  }) => _remote.fetch(sessionId: sessionId, plate: plate);
}
