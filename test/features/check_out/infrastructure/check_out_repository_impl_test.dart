import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_remote_data_source.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_repository_impl.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_sync_outbox.dart';

class _FakeRemote implements CheckOutRemoteDataSource {
  _FakeRemote({this.receiptToReturn, this.error});

  final CheckOutReceipt? receiptToReturn;
  final Failure? error;
  String? tokenUsed;
  DateTime? clientExitTimeUsed;

  @override
  Future<List<OpenSession>> listOpenSessions(String token) async {
    tokenUsed = token;
    return const [];
  }

  @override
  Future<CheckOutReceipt> checkOut(
    String token,
    int sessionId, {
    DateTime? clientExitTime,
  }) async {
    tokenUsed = token;
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

  AuthSession authenticatedSession() => const AuthSession(
        user: User(id: 1, username: 'op', displayName: 'Op', role: UserRole.operator),
        token: 'token-1',
      );

  test('Success: checkOut returns the remote-mapped CheckOutReceipt, no clientExitTime sent', () async {
    final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
    final remote = _FakeRemote(receiptToReturn: receipt);
    final repository = CheckOutRepositoryImpl(auth, remote, FakeSyncOutbox());

    final result = await repository.checkOut(1);

    expect(result, receipt);
    expect(remote.tokenUsed, 'token-1');
    expect(remote.clientExitTimeUsed, isNull);
  });

  test(
    'Failure: NetworkFailure queues a checkOut/close mutation and returns a pending receipt instead of rethrowing',
    () async {
      final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
      final remote = _FakeRemote(error: const NetworkFailure('offline'));
      final outbox = FakeSyncOutbox();
      final repository = CheckOutRepositoryImpl(auth, remote, outbox);

      final result = await repository.checkOut(1);

      expect(result.pendingSync, isTrue);
      expect(result.amountCharged, isNull);
      expect(result.ticketNumber, isNull);
      expect(outbox.enqueued, hasLength(1));
      expect(outbox.enqueued.single.entityType, 'checkOut');
      expect(outbox.enqueued.single.operation, 'close');
      expect(outbox.enqueued.single.entityId, 1);
      final payload = jsonDecode(outbox.enqueued.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['client_exit_time'], isNotNull);
    },
  );

  test(
    'Security/robustness: the queued client_exit_time is the attempt time, captured at call time',
    () async {
      final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
      final remote = _FakeRemote(error: const NetworkFailure('offline'));
      final outbox = FakeSyncOutbox();
      final repository = CheckOutRepositoryImpl(auth, remote, outbox);

      final before = DateTime.now();
      await repository.checkOut(1);
      final after = DateTime.now();

      final payload = jsonDecode(outbox.enqueued.single.payloadJson!) as Map<String, dynamic>;
      final capturedTime = DateTime.parse(payload['client_exit_time'] as String);

      expect(capturedTime.isBefore(before), isFalse);
      expect(capturedTime.isAfter(after), isFalse);
    },
  );

  test(
    'Failure: a non-network failure still propagates un-queued',
    () async {
      final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
      final remote = _FakeRemote(error: const ValidationFailure('Conflict'));
      final outbox = FakeSyncOutbox();
      final repository = CheckOutRepositoryImpl(auth, remote, outbox);

      await expectLater(
        repository.checkOut(1),
        throwsA(isA<ValidationFailure>()),
      );
      expect(outbox.enqueued, isEmpty);
    },
  );

  test(
    'Security: missing token throws AuthenticationFailure before any network call',
    () async {
      final auth = FakeAuthRepository();
      final remote = _FakeRemote(receiptToReturn: receipt);
      final repository = CheckOutRepositoryImpl(auth, remote, FakeSyncOutbox());

      expect(
        () => repository.checkOut(1),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(remote.tokenUsed, isNull);
    },
  );
}
