import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import 'tariff_local_data_source.dart';
import 'tariff_remote_data_source.dart';

/// Replays queued tariff `update`/`delete` directly against the API.
class TariffMutationReplayer extends MutationReplayer {
  TariffMutationReplayer(this._remote, this._local);

  final TariffRemoteDataSource _remote;
  final TariffLocalDataSource _local;

  @override
  MutationEntity get entity => MutationEntity.tariff;

  @override
  Future<void> replay(PendingMutation mutation) async {
    final id = mutation.entityId!;
    if (mutation.operation == MutationOperation.delete) {
      return _remote.delete(id);
    }
    await _local.upsert(await _remote.update(id, mutation.decodePayload()));
  }
}
