import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/check_out/application/check_out_vehicle.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';

class _FakeRepository implements CheckOutRepository {
  final List<int> checkedOut = [];

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
  }) async => const PagedResult([]);

  @override
  Future<CheckOutReceipt> checkOut(int sessionId) async {
    checkedOut.add(sessionId);
    return CheckOutReceipt(
      id: sessionId,
      plate: 'ABC123',
      entryTime: DateTime.utc(2026),
      exitTime: DateTime.utc(2026),
      amountCharged: 1000,
      ticketNumber: 'T-1',
    );
  }
}

void main() {
  test('Success: closes a server-known session', () async {
    final repository = _FakeRepository();

    final receipt = await CheckOutVehicle(repository)(5);

    expect(receipt.id, 5);
    expect(repository.checkedOut, [5]);
  });

  test(
    'Failure: a still-queued (negative id) check-in cannot be checked out',
    () async {
      final repository = _FakeRepository();

      await expectLater(
        CheckOutVehicle(repository)(-123),
        throwsA(isA<ValidationFailure>()),
      );
      expect(repository.checkedOut, isEmpty);
    },
  );

  test('Security: id 0 is never sent to the server', () async {
    final repository = _FakeRepository();

    await expectLater(
      CheckOutVehicle(repository)(0),
      throwsA(isA<ValidationFailure>()),
    );
    expect(repository.checkedOut, isEmpty);
  });
}
