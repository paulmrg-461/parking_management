import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../core/pagination/paged_result.dart';
import '../../../core/lot/lot_session.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
import '../domain/entities/capacity_snapshot.dart';
import '../domain/entities/check_out_preview.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/occupancy_snapshot.dart';
import '../domain/entities/open_session.dart';
import '../domain/entities/today_summary.dart';
import '../domain/repositories/check_out_repository.dart';
import 'check_out_remote_data_source.dart';

/// Check-out tries remote first, same as before. On `NetworkFailure` it now
/// queues a `checkOut`/`close` mutation instead of rethrowing, carrying the
/// attempt time as `client_exit_time` so the fare is computed against when
/// the operator actually acted, not whenever the device reconnects (see
/// `design.md`). The immediate result is a pending receipt with no amount.
class CheckOutRepositoryImpl implements CheckOutRepository {
  CheckOutRepositoryImpl(this._remote, this._outbox, this._lots);

  final CheckOutRemoteDataSource _remote;
  final SyncOutbox _outbox;
  final LotSession _lots;

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
    String? plate,
  }) => _remote.listOpenSessions(limit: limit, offset: offset, plate: plate);

  @override
  Future<OccupancySnapshot> occupancy() => _remote.occupancy();

  @override
  Future<CapacitySnapshot> capacitySnapshot() => _remote.capacitySnapshot();

  @override
  Future<TodaySummary> todaySummary() => _remote.todaySummary();

  @override
  Future<CheckOutPreview> preview(int sessionId) => _remote.preview(sessionId);

  @override
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    String paymentMethod = 'cash',
    int discountAmount = 0,
    String? discountReason,
    bool lostTicket = false,
    String? lostTicketReason,
  }) async {
    // Same key for the online attempt and any queued replay: a response lost
    // after the server committed must not become a dead letter on retry.
    final clientRef = newClientRef();
    final exitTime = DateTime.now().toUtc();
    try {
      return await _remote.checkOut(
        sessionId,
        idempotencyKey: clientRef,
        paymentMethod: paymentMethod,
        discountAmount: discountAmount,
        discountReason: discountReason,
        lostTicket: lostTicket,
        lostTicketReason: lostTicketReason,
      );
    } on NetworkFailure {
      return _queueCheckOut(
        sessionId,
        clientRef: clientRef,
        exitTime: exitTime,
        paymentMethod: paymentMethod,
        discountAmount: discountAmount,
        discountReason: discountReason,
        lostTicket: lostTicket,
        lostTicketReason: lostTicketReason,
      );
    }
  }

  /// Queues the attempt time captured BEFORE the first request (never at
  /// replay) plus the `client_ref` used by that attempt, which becomes the
  /// `Idempotency-Key` of every replay.
  Future<CheckOutReceipt> _queueCheckOut(
    int sessionId, {
    required String clientRef,
    required DateTime exitTime,
    required String paymentMethod,
    required int discountAmount,
    required String? discountReason,
    required bool lostTicket,
    required String? lostTicketReason,
  }) async {
    await _outbox.enqueue(
      PendingMutation(
        entityType: MutationEntity.checkOut,
        operation: MutationOperation.close,
        entityId: sessionId,
        payloadJson: jsonEncode({
          'client_exit_time': exitTime.toIso8601String(),
          'client_ref': clientRef,
          'lot_id': ?_lots.activeLotId,
          'payment_method': paymentMethod,
          'discount_amount': discountAmount,
          'discount_reason': ?discountReason,
          if (lostTicket) ...{
            'lost_ticket': true,
            'lost_ticket_reason': ?lostTicketReason,
          },
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
      paymentMethod: paymentMethod,
      discountAmount: discountAmount,
      discountReason: discountReason,
      lostTicket: lostTicket,
      pendingSync: true,
    );
  }
}
