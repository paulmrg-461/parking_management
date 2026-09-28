import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
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

  test('Security: only one row is requested (count via X-Total-Count)', () async {
    final repository = _CountingRepository(sessions: _sessions(3));
    final cubit = DashboardCubit(repository);

    await cubit.load();

    expect(repository.lastLimit, 1);
    expect(cubit.state, const DashboardLoaded(openSessions: 3));
  });
}

class _CountingRepository extends FakeCheckOutRepository {
  _CountingRepository({super.sessions});

  int? lastLimit;

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({int offset = 0, int limit = 50}) {
    lastLimit = limit;
    return super.listOpenSessions(offset: offset, limit: limit);
  }
}
