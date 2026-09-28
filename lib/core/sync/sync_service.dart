import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../error/failure.dart';
import '../network/connectivity_service.dart';
import 'client_ref.dart';
import 'mutation_replayer.dart';
import 'pending_mutation.dart';
import 'sync_outbox.dart';

/// Drains the [SyncOutbox] once connectivity is available.
///
/// Policy per entry:
/// - success → removed
/// - [ServerFailure] (5xx/429/timeout) or unknown [Failure] → retried with
///   exponential backoff (2^n s, capped at [maxBackoff]); dead-lettered after
///   [maxAttempts]
/// - [ValidationFailure] (409/422/…) or unexpected error → dead-lettered at once
/// - [NetworkFailure] / [AuthenticationFailure] → drain stops, entry untouched
///
/// A dead letter never blocks the queue: the loop continues with the next
/// entry. Concurrent [flush] calls share a single in-flight drain.
class SyncService {
  SyncService(
    this._outbox,
    this._connectivity,
    List<MutationReplayer> replayers, {
    DateTime Function()? clock,
  }) : _replayers = {for (final r in replayers) r.entity: r},
       _clock = clock ?? DateTime.now;

  static const maxAttempts = 5;
  static const maxBackoff = Duration(minutes: 5);
  static const _idempotent = {MutationEntity.checkIn, MutationEntity.checkOut};

  final SyncOutbox _outbox;
  final ConnectivityService _connectivity;
  final Map<MutationEntity, MutationReplayer> _replayers;
  final DateTime Function() _clock;
  StreamSubscription<bool>? _subscription;
  Timer? _retryTimer;
  Future<void>? _inFlight;

  /// Flushes now and whenever the device comes back online.
  void start() {
    _subscription ??= _connectivity.onConnectivityChanged.listen((online) {
      if (online) {
        _kick();
      }
    });
    _kick();
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> flush() =>
      _inFlight ??= _drain().whenComplete(() => _inFlight = null);

  /// Fire-and-forget flush (connectivity events, retry timer): errors are
  /// dropped here, entries stay queued for the next trigger.
  void _kick() => flush().ignore();

  /// Drops a dead letter after letting its replayer clean up side files.
  Future<void> discard(int key) async {
    for (final entry in await _outbox.listDeadLetters()) {
      if (entry.key == key) {
        await _replayers[entry.value.entityType]?.discard(entry.value);
        await _outbox.remove(key);
      }
    }
  }

  /// 2^[attempts] seconds, capped at [maxBackoff].
  static Duration backoffFor(int attempts) {
    final seconds = pow(2, attempts).toInt();
    return Duration(seconds: min(seconds, maxBackoff.inSeconds));
  }

  Future<void> _drain() async {
    if (!await _connectivity.isOnline()) {
      return;
    }
    for (final entry in await _outbox.listPending()) {
      if (_isDue(entry.value) && !await _attempt(await _withKey(entry))) {
        break;
      }
    }
    await _scheduleRetry();
  }

  bool _isDue(PendingMutation mutation) {
    final next = mutation.nextAttemptAt;
    return next == null || !next.isAfter(_clock());
  }

  /// Returns `false` when the whole drain must stop.
  Future<bool> _attempt(OutboxEntry entry) async {
    try {
      await _replay(entry.value);
      await _outbox.remove(entry.key);
      return true;
    } on Failure catch (failure) {
      return _onFailure(entry, failure);
    } catch (error) {
      await _park(entry, 'Unexpected error: ${error.runtimeType}');
      return true;
    }
  }

  Future<void> _replay(PendingMutation mutation) {
    final replayer = _replayers[mutation.entityType];
    if (replayer == null) {
      throw StateError('No replayer for ${mutation.entityType.name}');
    }
    return replayer.replay(mutation);
  }

  Future<bool> _onFailure(OutboxEntry entry, Failure failure) async {
    switch (failure) {
      case ServerFailure():
        await _retryLater(entry, failure.message);
      case NetworkFailure() || AuthenticationFailure():
        return false;
      case ValidationFailure():
        await _park(entry, failure.message);
      default:
        await _retryLater(entry, failure.message);
    }
    return true;
  }

  Future<void> _retryLater(OutboxEntry entry, String message) async {
    final attempts = entry.value.attempts + 1;
    if (attempts >= maxAttempts) {
      return _park(entry, message);
    }
    final next = _clock().add(backoffFor(attempts));
    await _outbox.replace(
      entry.key,
      entry.value.recordFailure(message, nextAttemptAt: next),
    );
  }

  Future<void> _park(OutboxEntry entry, String message) => _outbox.replace(
    entry.key,
    entry.value.recordFailure(message, deadLettered: true),
  );

  /// Legacy check-in/check-out entries may lack a `client_ref`; one is
  /// generated and persisted BEFORE the first replay so every retry sends
  /// the same `Idempotency-Key`.
  Future<OutboxEntry> _withKey(OutboxEntry entry) async {
    final mutation = entry.value;
    final payload = mutation.decodePayload();
    if (!_idempotent.contains(mutation.entityType) ||
        payload['client_ref'] is String) {
      return entry;
    }
    payload['client_ref'] = newClientRef();
    final keyed = mutation.withPayload(jsonEncode(payload));
    await _outbox.replace(entry.key, keyed);
    return MapEntry(entry.key, keyed);
  }

  Future<void> _scheduleRetry() async {
    _retryTimer?.cancel();
    final due = (await _outbox.listPending())
        .map((entry) => entry.value.nextAttemptAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    if (due != null) {
      _retryTimer = Timer(due.difference(_clock()), _kick);
    }
  }
}
