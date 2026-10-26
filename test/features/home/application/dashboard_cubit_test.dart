import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';

import '../../../helpers/fake_check_out_repository.dart';

List<OpenSession> _sessions(int count) => [
  for (var i = 1; i <= count; i++)
    OpenSession(id: i, vehicleId: i, entryTime: DateTime(2026)),
];

void main() {
  test('Success: occupancy is the server total of open sessions', () async {
    final cubit = DashboardCubit(FakeCheckOutRepository(sessions: _sessions(7)));

    await cubit.load();

    expect(cubit.state, const DashboardLoaded(openSessions: 7));
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

    expect(cubit.state, const DashboardLoaded(openSessions: 7));
  });

  test('Security: occupancy uses the dedicated snapshot RPC', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(3));
    final cubit = DashboardCubit(repository);

    await cubit.load();

    expect(repository.occupancyCalls, 1);
    expect(cubit.state, const DashboardLoaded(openSessions: 3));
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
}
