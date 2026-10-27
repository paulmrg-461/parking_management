import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_mutation_replayer.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_remote_data_source.dart';

class _FakeRemote implements CheckOutRemoteDataSource {
  _FakeRemote([this.error]);

  final Failure? error;
  int? sessionId;
  DateTime? clientExitTime;
  String? idempotencyKey;
  String? paymentMethod;
  int discountAmount = 0;
  String? discountReason;

  @override
  Future<TodaySummary> todaySummary() async => TodaySummary.empty;

  @override
  Future<SlotBoard> slotBoard() async => SlotBoard.empty;

  @override
  Future<CapacitySnapshot> capacitySnapshot() async => CapacitySnapshot.empty;

  @override
  Future<OccupancySnapshot> occupancy() async =>
      const OccupancySnapshot(totalOpen: 0, totalCapacity: 0);

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    required int limit,
    required int offset,
    String? plate,
  }) async => const PagedResult([]);

  @override
  Future<CheckOutPreview> preview(int sessionId) async =>
      CheckOutPreview(sessionId: sessionId, amount: 5000);


  @override
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    DateTime? clientExitTime,
    String? idempotencyKey,
    String paymentMethod = 'cash',
    int discountAmount = 0,
    String? discountReason,
    bool lostTicket = false,
    String? lostTicketReason,
    int? lotId,
  }) async {
    this.sessionId = sessionId;
    this.clientExitTime = clientExitTime;
    this.idempotencyKey = idempotencyKey;
    this.paymentMethod = paymentMethod;
    this.discountAmount = discountAmount;
    this.discountReason = discountReason;
    if (error != null) {
      throw error!;
    }
    return CheckOutReceipt(
      id: sessionId,
      plate: 'ABC123',
      entryTime: DateTime(2026, 1, 1),
      exitTime: DateTime(2026, 1, 1, 2),
      amountCharged: 6000,
      ticketNumber: 'TCK-000001',
    );
  }
}

PendingMutation _queued(String payload) => PendingMutation(
  entityType: MutationEntity.checkOut,
  operation: MutationOperation.close,
  entityId: 5,
  payloadJson: payload,
  enqueuedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  test(
    'Success: replays with the original client_exit_time and Idempotency-Key',
    () async {
      final remote = _FakeRemote();

      await CheckOutMutationReplayer(remote).replay(
        _queued(
          '{"client_exit_time":"2026-01-01T10:00:00.000","client_ref":"k1","payment_method":"card","discount_amount":1000,"discount_reason":"cortesia"}',
        ),
      );

      expect(remote.sessionId, 5);
      expect(remote.clientExitTime, DateTime.parse('2026-01-01T10:00:00.000'));
      expect(remote.idempotencyKey, 'k1');
      expect(remote.paymentMethod, 'card');
      expect(remote.discountAmount, 1000);
      expect(remote.discountReason, 'cortesia');
    },
  );

  test('Failure: a rejected replay propagates the failure', () async {
    final remote = _FakeRemote(
      const ValidationFailure('Session already closed'),
    );

    await expectLater(
      CheckOutMutationReplayer(remote).replay(
        _queued(
          '{"client_exit_time":"2026-01-01T10:00:00.000","client_ref":"k1","payment_method":"card","discount_amount":1000,"discount_reason":"cortesia"}',
        ),
      ),
      throwsA(const ValidationFailure('Session already closed')),
    );
  });

  test('Security: the exit time is never recaptured at replay time', () async {
    final remote = _FakeRemote();

    await CheckOutMutationReplayer(remote).replay(
      _queued(
        '{"client_exit_time":"2020-05-05T05:05:05.000","client_ref":"k1"}',
      ),
    );

    expect(remote.clientExitTime, DateTime.parse('2020-05-05T05:05:05.000'));
  });
}
