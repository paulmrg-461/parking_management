import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/fake_vehicle_repository.dart';

List<OpenSession> _sessions(int count) => [
  for (var i = 1; i <= count; i++)
    OpenSession(id: i, vehicleId: i, entryTime: DateTime(2026)),
];

void main() {
  test('Success: occupancy is the server total of open sessions', () async {
    final cubit = DashboardCubit(FakeCheckOutRepository(sessions: _sessions(7)));

    await cubit.load();

    expect((cubit.state as DashboardLoaded).openSessions, 7);
  });

  test('Failure: a failed load reports the failure', () async {
    final cubit = DashboardCubit(
      FakeCheckOutRepository(listError: const NetworkFailure('offline')),
    );

    await cubit.load();

    expect(cubit.state, isA<DashboardFailure>());
  });

  test('Failure: a failed refresh keeps the last known occupancy', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(7));
    final cubit = DashboardCubit(repository);

    await cubit.load();
    repository.listError = const NetworkFailure('offline');
    await cubit.load();

    expect((cubit.state as DashboardLoaded).openSessions, 7);
  });

  test('Security: occupancy uses the dedicated snapshot RPC', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(3));
    final cubit = DashboardCubit(repository);

    await cubit.load();

    expect(repository.occupancyCalls, 1);
    expect((cubit.state as DashboardLoaded).openSessions, 3);
  });

  test('Success: the daily summary lands in the loaded state', () async {
    final cubit = DashboardCubit(
      FakeCheckOutRepository(
        sessions: _sessions(2),
        today: const TodaySummary(revenue: 25000, entries: 3, exits: 2),
      ),
    );

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(state.today.revenue, 25000);
    expect(state.today.exits, 2);
  });

  test('Failure: a broken summary keeps occupancy and shows zeros', () async {
    final cubit = DashboardCubit(
      FakeCheckOutRepository(
        sessions: _sessions(2),
        todayError: const NetworkFailure('offline'),
      ),
    );

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(state.openSessions, 2);
    expect(state.today, TodaySummary.empty);
  });

  test('Success: the capacity snapshot and inside list feed the home', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(3))
      ..capacityToReturn = const CapacitySnapshot(
        carOpen: 2,
        carCapacity: 20,
        motoOpen: 1,
        motoCapacity: 10,
        keysOpen: 1,
        keyCapacity: 5,
      );
    final vehicles = FakeVehicleRepository(const [
      Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
      Vehicle(id: 2, plate: 'XYZ999', categoryId: 1),
    ]);
    final cubit = DashboardCubit(repository, vehicles);

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(state.capacity.carCapacity, 20);
    expect(state.capacity.motosFull, isFalse);
    expect(state.sessions, hasLength(3));
    expect(state.plateOf(state.sessions.first), 'ABC123');
  });

  test('Failure: a broken capacity snapshot keeps the rest of the home', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(2))
      ..capacityError = const NetworkFailure('offline');
    final cubit = DashboardCubit(repository);

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(state.openSessions, 2);
    expect(state.capacity, CapacitySnapshot.empty);
  });
}
