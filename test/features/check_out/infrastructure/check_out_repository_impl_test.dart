import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_remote_data_source.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_repository_impl.dart';

import '../../../helpers/fake_auth_repository.dart';

class _FakeRemote implements CheckOutRemoteDataSource {
  _FakeRemote({this.receiptToReturn, this.error});

  final CheckOutReceipt? receiptToReturn;
  final Failure? error;
  String? tokenUsed;

  @override
  Future<List<OpenSession>> listOpenSessions(String token) async {
    tokenUsed = token;
    return const [];
  }

  @override
  Future<CheckOutReceipt> checkOut(String token, int sessionId) async {
    tokenUsed = token;
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

  test('Success: checkOut returns the remote-mapped CheckOutReceipt', () async {
    final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
    final remote = _FakeRemote(receiptToReturn: receipt);
    final repository = CheckOutRepositoryImpl(auth, remote);

    final result = await repository.checkOut(1);

    expect(result, receipt);
    expect(remote.tokenUsed, 'token-1');
  });

  test('Failure: checkOut rethrows the failure raised by the remote source', () async {
    final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
    final remote = _FakeRemote(error: const NetworkFailure('offline'));
    final repository = CheckOutRepositoryImpl(auth, remote);

    expect(
      () => repository.checkOut(1),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test(
    'Security: missing token throws AuthenticationFailure before any network call',
    () async {
      final auth = FakeAuthRepository();
      final remote = _FakeRemote(receiptToReturn: receipt);
      final repository = CheckOutRepositoryImpl(auth, remote);

      expect(
        () => repository.checkOut(1),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(remote.tokenUsed, isNull);
    },
  );
}
