import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/check_out/application/check_out_vehicle.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';

class _FakeRepository implements CheckOutRepository {
  final List<int> checkedOut = [];

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
    int offset = 0,
    int limit = defaultPageSize,
    String? plate,
  }) async => const PagedResult([]);

  @override
  Future<CheckOutPreview> preview(int sessionId) async =>
      CheckOutPreview(sessionId: sessionId, amount: 5000);


  @override
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    String paymentMethod = 'cash',
    int discountAmount = 0,
    String? discountReason,
    bool lostTicket = false,
    String? lostTicketReason,
  }) async {
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
