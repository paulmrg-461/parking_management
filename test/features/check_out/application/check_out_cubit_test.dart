import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/check_out/application/check_out_cubit.dart';
import 'package:parking_management/features/check_out/application/check_out_vehicle.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/fake_vehicle_repository.dart';

class _FakeCheckOutRepository implements CheckOutRepository {
  List<OpenSession> sessions = [];
  int? total;
  Failure? listError;
  Failure? checkOutError;
  CheckOutReceipt? receipt;
  final List<int> offsets = [];

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
  }) async {
    offsets.add(offset);
    if (listError != null) {
      throw listError!;
    }
    return PagedResult(
      sessions.skip(offset).take(limit).toList(),
      total: total,
    );
  }

  @override
  Future<CheckOutReceipt> checkOut(int sessionId) async {
    if (checkOutError != null) {
      throw checkOutError!;
    }
    sessions = sessions.where((s) => s.id != sessionId).toList();
    return receipt!;
  }
}

OpenSession _session(int id, int vehicleId) =>
    OpenSession(id: id, vehicleId: vehicleId, entryTime: DateTime.utc(2026));

final _receipt = CheckOutReceipt(
  id: 1,
  plate: 'ABC123',
  entryTime: DateTime.utc(2026),
  exitTime: DateTime.utc(2026, 1, 1, 2),
  amountCharged: 6000,
  ticketNumber: 'TCK-000001',
);

void main() {
  late _FakeCheckOutRepository repository;
  late FakeVehicleRepository vehicles;
  late CheckOutCubit cubit;

  setUp(() {
    repository = _FakeCheckOutRepository()
      ..sessions = [_session(1, 10), _session(2, 20)]
      ..receipt = _receipt;
    vehicles = FakeVehicleRepository(const [
      Vehicle(id: 10, plate: 'ABC123', categoryId: 1),
      Vehicle(id: 20, plate: 'XYZ999', categoryId: 1),
    ]);
    cubit = CheckOutCubit(
      CheckOutVehicle(repository),
      repository,
      vehicles,
      searchDebounce: Duration.zero,
    );
  });

  tearDown(() => cubit.close());

  CheckOutLoaded loaded() => cubit.state as CheckOutLoaded;

  test(
    'Success: load precomputes vehicleId -> plate for every session',
    () async {
      await cubit.loadOpenSessions();

      expect(loaded().plates, {10: 'ABC123', 20: 'XYZ999'});
      expect(loaded().plateOf(loaded().visible.first), 'ABC123');
      expect(loaded().visible, hasLength(2));
    },
  );

  test('Success: search filters in the cubit after the debounce', () async {
    await cubit.loadOpenSessions();

    cubit.search('xyz');
    await Future<void>.delayed(Duration.zero);

    expect(loaded().query, 'xyz');
    expect(loaded().visible.map((s) => s.id), [2]);
    expect(loaded().sessions, hasLength(2));
  });

  test(
    'Success: check-out reports the receipt and drops the closed session',
    () async {
      await cubit.loadOpenSessions();

      await cubit.checkOut(1);

      expect(
        loaded().submission,
        SubmissionSucceeded<CheckOutReceipt>(_receipt),
      );
      expect(loaded().sessions.map((s) => s.id), [2]);
    },
  );

  test(
    'Failure: a failed check-out keeps the list and reports the error',
    () async {
      await cubit.loadOpenSessions();
      repository.checkOutError = const ValidationFailure(
        'Session already closed',
      );

      await cubit.checkOut(1);

      expect(loaded().sessions, hasLength(2));
      expect(
        loaded().submission,
        const SubmissionFailed('Session already closed'),
      );
    },
  );

  test('Failure: a failed first load is CheckOutFailure', () async {
    repository.listError = const NetworkFailure('offline');

    await cubit.loadOpenSessions();

    expect(cubit.state, const CheckOutFailure('offline'));
  });

  test(
    'Failure: unresolvable plates fall back without failing the load',
    () async {
      vehicles.listError = const NetworkFailure('offline');

      await cubit.loadOpenSessions();

      expect(loaded().plates, isEmpty);
      expect(loaded().plateOf(loaded().visible.first), 'Vehicle #10');
    },
  );

  test(
    'Success: loadMore appends the next page while X-Total-Count says so',
    () async {
      repository
        ..sessions = [for (var i = 1; i <= 60; i++) _session(i, 10)]
        ..total = 60;

      await cubit.loadOpenSessions();
      expect(loaded().hasMore, isTrue);

      await cubit.loadMore();

      expect(repository.offsets, [0, 50]);
      expect(loaded().sessions, hasLength(60));
      expect(loaded().hasMore, isFalse);
    },
  );

  test(
    'Security: without X-Total-Count no extra page is ever requested',
    () async {
      await cubit.loadOpenSessions();

      await cubit.loadMore();

      expect(loaded().hasMore, isFalse);
      expect(repository.offsets, [0]);
    },
  );

  test(
    'Security: a pending-sync (negative id) session is rejected, list intact',
    () async {
      await cubit.loadOpenSessions();

      await cubit.checkOut(-7);

      expect(loaded().submission, isA<SubmissionFailed>());
      expect(loaded().sessions, hasLength(2));
    },
  );
}
