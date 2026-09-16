import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/open_session.dart';
import '../domain/repositories/check_out_repository.dart';
import 'check_out_remote_data_source.dart';

/// Check-out tries remote first, same as before. On `NetworkFailure` it now
/// queues a `checkOut`/`close` mutation instead of rethrowing, carrying the
/// attempt time as `client_exit_time` so the fare is computed against when
/// the operator actually acted, not whenever the device reconnects (see
/// `design.md`). The immediate result is a pending receipt with no amount.
class CheckOutRepositoryImpl implements CheckOutRepository {
  CheckOutRepositoryImpl(this._auth, this._remote, this._outbox);

  final AuthRepository _auth;
  final CheckOutRemoteDataSource _remote;
  final SyncOutbox _outbox;

  @override
  Future<List<OpenSession>> listOpenSessions() async {
    return _remote.listOpenSessions(await _currentToken());
  }

  @override
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    DateTime? clientExitTime,
  }) async {
    try {
      return await _remote.checkOut(
        await _currentToken(),
        sessionId,
        clientExitTime: clientExitTime,
      );
    } on NetworkFailure {
      return _queueCheckOut(sessionId, clientExitTime);
    }
  }

  /// [clientExitTime] is only non-null when this call is itself a replay
  /// (see `SyncService._replayCheckOut`); in that case it is the *original*
  /// attempt time and is reused as-is, never recaptured, so a failing replay
  /// does not silently shift the exit time forward.
  Future<CheckOutReceipt> _queueCheckOut(
    int sessionId,
    DateTime? clientExitTime,
  ) async {
    final exitTime = clientExitTime ?? DateTime.now();
    await _outbox.enqueue(
      PendingMutation(
        entityType: 'checkOut',
        operation: 'close',
        entityId: sessionId,
        payloadJson: jsonEncode({
          'client_exit_time': exitTime.toIso8601String(),
        }),
        enqueuedAt: DateTime.now(),
      ),
    );
    // `plate`/`entryTime` are not known offline (this call only has
    // `sessionId`); `CheckOutPage` never renders them when `pendingSync` is
    // true, so a placeholder here is safe.
    return CheckOutReceipt(
      id: sessionId,
      plate: '',
      entryTime: exitTime,
      exitTime: exitTime,
      amountCharged: null,
      ticketNumber: null,
      pendingSync: true,
    );
  }

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }
}
