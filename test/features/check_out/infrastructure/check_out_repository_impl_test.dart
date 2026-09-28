import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_remote_data_source.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_repository_impl.dart';

import '../../../helpers/fake_sync_outbox.dart';

class _FakeRemote implements CheckOutRemoteDataSource {
  _FakeRemote({this.receiptToReturn, this.error});

  final CheckOutReceipt? receiptToReturn;
  final Failure? error;
  DateTime? clientExitTimeUsed;

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
    clientExitTimeUsed = clientExitTime;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return receiptToReturn!;
  }
}

void main() {
  final receipt = CheckOutReceipt(
    id: 1,
    plate: 'ABC123',
    entryTime: DateTime(2026, 1, 1),
    exitTime: DateTime(2026, 1, 1, 2),
    amountCharged: 6000,
    ticketNumber: 'TCK-000001',
  );

  test('Success: checkOut returns the remote-mapped CheckOutReceipt, no clientExitTime sent', () async {
    final remote = _FakeRemote(receiptToReturn: receipt);
    final repository = CheckOutRepositoryImpl(remote, FakeSyncOutbox());

    final result = await repository.checkOut(1);

    expect(result, receipt);
    expect(remote.clientExitTimeUsed, isNull);
  });

  test('Failure: NetworkFailure queues a checkOut/close mutation and returns a pending receipt instead of rethrowing', () async {
    final remote = _FakeRemote(error: const NetworkFailure('offline'));
    final outbox = FakeSyncOutbox();
    final repository = CheckOutRepositoryImpl(remote, outbox);

    final result = await repository.checkOut(1);

    expect(result.pendingSync, isTrue);
    expect(result.amountCharged, isNull);
    expect(result.ticketNumber, isNull);
    expect(outbox.enqueued, hasLength(1));
    expect(outbox.enqueued.single.entityType, MutationEntity.checkOut);
    expect(outbox.enqueued.single.operation, MutationOperation.close);
    expect(outbox.enqueued.single.entityId, 1);
    final payload =
        jsonDecode(outbox.enqueued.single.payloadJson!) as Map<String, dynamic>;
    expect(payload['client_exit_time'], endsWith('Z'));
    expect(payload['client_ref'], isA<String>());
  });

  test(
    'Security: each queued check-out gets its own idempotency client_ref',
    () async {
      final remote = _FakeRemote(error: const NetworkFailure('offline'));
      final outbox = FakeSyncOutbox();
      final repository = CheckOutRepositoryImpl(remote, outbox);

      await repository.checkOut(1);
      await repository.checkOut(2);

      final refs = outbox.enqueued
          .map((m) => m.decodePayload()['client_ref'] as String)
          .toSet();
      expect(refs, hasLength(2));
    },
  );

  test('Security/robustness: the queued client_exit_time is the attempt time, captured at call time', () async {
    final remote = _FakeRemote(error: const NetworkFailure('offline'));
    final outbox = FakeSyncOutbox();
    final repository = CheckOutRepositoryImpl(remote, outbox);

    final before = DateTime.now();
    await repository.checkOut(1);
    final after = DateTime.now();

    final payload =
        jsonDecode(outbox.enqueued.single.payloadJson!) as Map<String, dynamic>;
    final capturedTime = DateTime.parse(payload['client_exit_time'] as String);

    expect(capturedTime.isBefore(before), isFalse);
    expect(capturedTime.isAfter(after), isFalse);
  });

  test('Failure: a non-network failure still propagates un-queued', () async {
    final remote = _FakeRemote(error: const ValidationFailure('Conflict'));
    final outbox = FakeSyncOutbox();
    final repository = CheckOutRepositoryImpl(remote, outbox);

    await expectLater(
      repository.checkOut(1),
      throwsA(isA<ValidationFailure>()),
    );
    expect(outbox.enqueued, isEmpty);
  });

  test(
    'Security: an expired session (401) is rethrown, never queued offline',
    () async {
      final outbox = FakeSyncOutbox();
      final remote = _FakeRemote(
        error: const AuthenticationFailure('Invalid credentials'),
      );
      final repository = CheckOutRepositoryImpl(remote, outbox);

      await expectLater(
        repository.checkOut(1),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(outbox.enqueued, isEmpty);
    },
  );
}
