import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import 'check_out_remote_data_source.dart';

/// Replays a queued check-out with the ORIGINAL attempt time (never
/// recaptured) and its `client_ref` as `Idempotency-Key`.
class CheckOutMutationReplayer extends MutationReplayer {
  CheckOutMutationReplayer(this._remote);

  final CheckOutRemoteDataSource _remote;

  @override
  MutationEntity get entity => MutationEntity.checkOut;

  @override
  Future<void> replay(PendingMutation mutation) async {
    final payload = mutation.decodePayload();
    await _remote.checkOut(
      mutation.entityId!,
      clientExitTime: DateTime.parse(payload['client_exit_time'] as String),
      idempotencyKey: payload['client_ref'] as String?,
    );
  }
}
