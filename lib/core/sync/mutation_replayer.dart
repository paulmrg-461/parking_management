import 'pending_mutation.dart';

/// Replays one kind of queued mutation straight against the remote API.
///
/// Implementations live in each feature's infrastructure layer and MUST let
/// every `Failure` propagate (never re-queue): `SyncService` owns the retry /
/// dead-letter policy.
abstract class MutationReplayer {
  MutationEntity get entity;

  /// Replays the mutation and returns the row version the server assigned
  /// (`null` when the entity has no version or the operation deleted it).
  Future<int?> replay(PendingMutation mutation);

  /// Cleans up local side artifacts when the operator discards a dead letter.
  Future<void> discard(PendingMutation mutation) async {}

  /// Refreshes the local cache with the row the server has (or removes it when
  /// [row] is null) after a conflict is resolved in the server's favour.
  Future<void> adoptServer(Map<String, dynamic>? row) async {}
}
