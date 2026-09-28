import 'pending_mutation.dart';

/// Replays one kind of queued mutation straight against the remote API.
///
/// Implementations live in each feature's infrastructure layer and MUST let
/// every `Failure` propagate (never re-queue): `SyncService` owns the retry /
/// dead-letter policy.
abstract class MutationReplayer {
  MutationEntity get entity;

  Future<void> replay(PendingMutation mutation);

  /// Cleans up local side artifacts when the operator discards a dead letter.
  Future<void> discard(PendingMutation mutation) async {}
}
