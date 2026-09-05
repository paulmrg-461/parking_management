import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/application/check_out_cubit.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';

class _FakeCheckOutRepository implements CheckOutRepository {
  _FakeCheckOutRepository({
    this.sessionsBeforeCheckOut = const [],
    this.sessionsAfterCheckOut = const [],
    this.receiptToReturn,
    this.error,
  });

  final List<OpenSession> sessionsBeforeCheckOut;
  final List<OpenSession> sessionsAfterCheckOut;
  final CheckOutReceipt? receiptToReturn;
  final Failure? error;
  bool checkOutCalled = false;

  @override
  Future<List<OpenSession>> listOpenSessions() async =>
      checkOutCalled ? sessionsAfterCheckOut : sessionsBeforeCheckOut;

  @override
  Future<CheckOutReceipt> checkOut(int sessionId) async {
    checkOutCalled = true;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return receiptToReturn!;
  }
}

void main() {
  final openSession = OpenSession(
    id: 1,
    vehicleId: 1,
    entryTime: DateTime(2026, 1, 1),
  );
  final receipt = CheckOutReceipt(
    id: 1,
    plate: 'ABC123',
    entryTime: DateTime(2026, 1, 1),
    exitTime: DateTime(2026, 1, 1, 2),
    amountCharged: 6000,
    ticketNumber: 'TCK-000001',
  );

  test(
    'Success: checkOut emits CheckOutSuccess with the receipt and refreshes the open-sessions list',
    () async {
      final repository = _FakeCheckOutRepository(
        sessionsBeforeCheckOut: [openSession],
        sessionsAfterCheckOut: const [],
        receiptToReturn: receipt,
      );
      final cubit = CheckOutCubit(repository);

      await cubit.checkOut(1);

      expect(cubit.state, CheckOutSuccess(receipt));
      expect(repository.checkOutCalled, isTrue);
    },
  );

  test(
    'Failure: checkOut emits CheckOutFailure when the repository throws NetworkFailure',
    () async {
      final cubit = CheckOutCubit(
        _FakeCheckOutRepository(error: const NetworkFailure('offline')),
      );

      await cubit.checkOut(1);

      expect(cubit.state, const CheckOutFailure('offline'));
    },
  );

  test(
    'Security: checking out an already-closed/unknown session maps to CheckOutFailure, not a crash',
    () async {
      final cubit = CheckOutCubit(
        _FakeCheckOutRepository(error: const ValidationFailure('Conflict')),
      );

      await cubit.checkOut(999);

      expect(cubit.state, const CheckOutFailure('Conflict'));
    },
  );
}
