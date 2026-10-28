import '../domain/entities/lot_profile.dart';
import '../domain/repositories/policy_repository.dart';
import 'policy_remote_data_source.dart';

class PolicyRepositoryImpl implements PolicyRepository {
  PolicyRepositoryImpl(this._remote);

  final PolicyRemoteDataSource _remote;

  @override
  Future<LotProfile> fetch(int lotId) => _remote.fetch(lotId);
}
