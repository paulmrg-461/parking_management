import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../core/pagination/paged_result.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
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
  CheckOutRepositoryImpl(this._remote, this._outbox);

  final CheckOutRemoteDataSource _remote;
  final SyncOutbox _outbox;

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
  }) => _remote.listOpenSessions(limit: limit, offset: offset);

  @override
  Future<CheckOutReceipt> checkOut(int sessionId) async {
    try {
      return await _remote.checkOut(sessionId);
    } on NetworkFailure {
      return _queueCheckOut(sessionId);
    }
  }

  /// Captures the attempt time NOW (never at replay) plus a `client_ref`
  /// that becomes the `Idempotency-Key` of every replay attempt.
  Future<CheckOutReceipt> _queueCheckOut(int sessionId) async {
    final exitTime = DateTime.now().toUtc();
    await _outbox.enqueue(
      PendingMutation(
        entityType: MutationEntity.checkOut,
        operation: MutationOperation.close,
        entityId: sessionId,
        payloadJson: jsonEncode({
          'client_exit_time': exitTime.toIso8601String(),
          'client_ref': newClientRef(),
        }),
        enqueuedAt: exitTime,
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
}
