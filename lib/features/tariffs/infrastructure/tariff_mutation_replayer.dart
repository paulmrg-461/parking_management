import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import 'models/tariff_dto.dart';
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
  Future<int?> replay(PendingMutation mutation) async {
    final id = mutation.entityId!;
    if (mutation.operation == MutationOperation.delete) {
      await _remote.delete(id, baseVersion: mutation.baseVersion);
      return null;
    }
    final updated = await _remote.update(
      id,
      mutation.decodePayload(),
      baseVersion: mutation.baseVersion,
    );
    await _local.upsert(updated);
    return updated.version;
  }

  @override
  Future<void> adoptServer(Map<String, dynamic>? row) async {
    if (row == null) {
      return;
    }
    final tariff = TariffDto.fromJson(row).toDomain();
    if (tariff.id != null) {
      await _local.upsert(tariff);
    }
  }
}
