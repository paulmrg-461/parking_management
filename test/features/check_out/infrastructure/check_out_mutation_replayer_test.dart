import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_mutation_replayer.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_remote_data_source.dart';

class _FakeRemote implements CheckOutRemoteDataSource {
  _FakeRemote([this.error]);

  final Failure? error;
  int? sessionId;
  DateTime? clientExitTime;
  String? idempotencyKey;

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    required int limit,
    required int offset,
  }) async => const PagedResult([]);

  @override
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    DateTime? clientExitTime,
    String? idempotencyKey,
  }) async {
    this.sessionId = sessionId;
    this.clientExitTime = clientExitTime;
    this.idempotencyKey = idempotencyKey;
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
          '{"client_exit_time":"2026-01-01T10:00:00.000","client_ref":"k1"}',
        ),
      );

      expect(remote.sessionId, 5);
      expect(remote.clientExitTime, DateTime.parse('2026-01-01T10:00:00.000'));
      expect(remote.idempotencyKey, 'k1');
    },
  );

  test('Failure: a rejected replay propagates the failure', () async {
    final remote = _FakeRemote(
      const ValidationFailure('Session already closed'),
    );

    await expectLater(
      CheckOutMutationReplayer(remote).replay(
        _queued(
          '{"client_exit_time":"2026-01-01T10:00:00.000","client_ref":"k1"}',
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
