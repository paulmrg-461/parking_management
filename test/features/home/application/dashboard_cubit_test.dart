import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/dashboard_trend.dart';
import 'package:parking_management/features/check_out/domain/entities/lot_setup_status.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';

import '../../../helpers/dashboard_fixtures.dart';
import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/fake_dashboard_cache.dart';

List<OpenSession> _sessions(int count) => [
  for (var i = 1; i <= count; i++)
    OpenSession(id: i, vehicleId: i, entryTime: DateTime(2026), plate: 'PLT$i'),
];

void main() {
  test('Success: occupancy is the server total of open sessions', () async {
    final cubit = DashboardCubit(
      FakeCheckOutRepository(sessions: _sessions(7)),
    );

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

  test('Success: the weekly trend lands in the loaded state', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(2))
      ..trend = DashboardTrend(
        days: [
          TrendDay(date: DateTime(2026, 11, 4), revenue: 8000, entries: 2),
          TrendDay(date: DateTime(2026, 11, 5), revenue: 12000, entries: 3),
        ],
      );
    final cubit = DashboardCubit(repository);

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(repository.trendCalls, 1);
    expect(state.trend.days, hasLength(2));
    expect(state.trend.totalRevenue, 20000);
  });

  test('Failure: a broken trend keeps the rest of the home', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(2))
      ..trendError = const NetworkFailure('offline');
    final cubit = DashboardCubit(repository);

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(state.openSessions, 2);
    expect(state.trend, DashboardTrend.empty);
  });

  test('Success: the dashboard extras load in parallel', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(1));
    final gate = Completer<void>();
    repository.todayGate = gate.future;
    final cubit = DashboardCubit(repository);

    final pending = cubit.load();
    await pumpEventQueue();

    // While today's summary is still waiting, the trend already ran: the
    // extras are concurrent instead of serialized behind it.
    expect(repository.trendCalls, 1);
    expect(repository.trendDaysRequested, 14);

    gate.complete();
    await pending;

    expect(cubit.state, isA<DashboardLoaded>());
  });

  test('Success: a complete load refreshes the offline cache', () async {
    final repository = FakeCheckOutRepository(
      sessions: _sessions(3),
      today: const TodaySummary(revenue: 25000, entries: 4),
    );
    final cache = FakeDashboardCache();
    final cubit = DashboardCubit(
      repository,
      cache: cache,
      clock: () => DateTime(2026, 11, 9, 16),
    );

    await cubit.load();
    await pumpEventQueue();

    expect(cache.writes, 1);
    expect(cache.snapshot!.today.revenue, 25000);
    expect(cache.snapshot!.occupancy.totalOpen, 3);
    expect(cache.snapshot!.cachedAt, DateTime(2026, 11, 9, 16));
  });

  test('Success: a failed load falls back to the cached KPIs', () async {
    final repository = FakeCheckOutRepository(
      listError: const NetworkFailure('offline'),
    );
    final cache = FakeDashboardCache()..snapshot = sampleDashboardSnapshot();
    final cubit = DashboardCubit(repository, cache: cache);

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(state.isStale, isTrue);
    expect(state.openSessions, 3);
    expect(state.today.revenue, 25000);
    expect(state.capacity.carCapacity, 10);
    expect(state.trend.days, hasLength(2));
    expect(state.slotBoard, SlotBoard.empty);
    expect(cache.reads, 1);
  });

  test('Failure: a failed load without a cache still reports it', () async {
    final repository = FakeCheckOutRepository(
      listError: const NetworkFailure('offline'),
    );
    final cubit = DashboardCubit(repository, cache: FakeDashboardCache());

    await cubit.load();

    expect(cubit.state, isA<DashboardFailure>());
  });

  test('Failure: an unreadable cache is ignored', () async {
    final repository = FakeCheckOutRepository(
      listError: const NetworkFailure('offline'),
    );
    final cache = FakeDashboardCache()..failRead = true;
    final cubit = DashboardCubit(repository, cache: cache);

    await cubit.load();

    expect(cubit.state, isA<DashboardFailure>());
  });

  test('Success: the setup checklist lands in the loaded state', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(1))
      ..setupToReturn = const LotSetupStatus(categories: 1);
    final cubit = DashboardCubit(repository);

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(state.setup.known, isTrue);
    expect(state.setup.hasCategories, isTrue);
    expect(state.setup.complete, isFalse);
  });

  test('Failure: a broken setup status is unknown', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(1))
      ..setupError = const NetworkFailure('offline');
    final cubit = DashboardCubit(repository);

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(state.setup, LotSetupStatus.unknown);
  });

  test('Security: a degraded load never overwrites the cache', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(2))
      ..trendError = const NetworkFailure('offline');
    final cache = FakeDashboardCache();
    final cubit = DashboardCubit(repository, cache: cache);

    await cubit.load();
    await pumpEventQueue();

    expect(cache.writes, 0);
    expect(cubit.state, isA<DashboardLoaded>());
  });

  test(
    'Success: the capacity snapshot and inside list feed the home',
    () async {
      final repository = FakeCheckOutRepository(sessions: _sessions(3))
        ..capacityToReturn = const CapacitySnapshot(
          carOpen: 2,
          carCapacity: 20,
          motoOpen: 1,
          motoCapacity: 10,
          keysOpen: 1,
          keyCapacity: 5,
        );
      final cubit = DashboardCubit(repository);

      await cubit.load();

      final state = cubit.state as DashboardLoaded;
      expect(state.capacity.carCapacity, 20);
      expect(state.capacity.motosFull, isFalse);
      expect(state.sessions, hasLength(3));
      expect(state.plateOf(state.sessions.first), 'PLT1');
    },
  );

  test(
    'Failure: a broken capacity snapshot keeps the rest of the home',
    () async {
      final repository = FakeCheckOutRepository(sessions: _sessions(2))
        ..capacityError = const NetworkFailure('offline');
      final cubit = DashboardCubit(repository);

      await cubit.load();

      final state = cubit.state as DashboardLoaded;
      expect(state.openSessions, 2);
      expect(state.capacity, CapacitySnapshot.empty);
    },
  );

  test('Success: the slot board lands in the loaded state', () async {
    final repository = FakeCheckOutRepository(sessions: _sessions(1))
      ..slotBoardToReturn = SlotBoard(
        carCapacity: 4,
        motoCapacity: 2,
        sessions: [
          SlotSession(sessionId: 9, plate: 'BRD001', entryTime: DateTime(2026)),
        ],
        holds: [SlotHold(plate: 'HOLD01', until: DateTime(2026, 1, 2))],
      );
    final cubit = DashboardCubit(repository);

    await cubit.load();

    final state = cubit.state as DashboardLoaded;
    expect(state.slotBoard.carCapacity, 4);
    expect(state.slotBoard.sessions.single.plate, 'BRD001');
    expect(state.slotBoard.holds.single.plate, 'HOLD01');
  });

  group('lot switches', () {
    test('Success: a slower load for the previous lot never overwrites the new one', () async {
      var lot = 1;
      final repository = FakeCheckOutRepository(sessions: _sessions(7));
      final cubit = DashboardCubit(repository, activeLot: () => lot);
      final gate = Completer<void>();
      repository.occupancyGate = gate.future;

      final stale = cubit.load();
      await Future<void>.delayed(Duration.zero);
      lot = 2;
      repository
        ..occupancyGate = null
        ..sessions = _sessions(2);
      await cubit.load();
      gate.complete();
      await stale;

      expect((cubit.state as DashboardLoaded).openSessions, 2);
    });

    test(
      'Failure: a failed load after a lot switch reports the failure',
      () async {
        var lot = 1;
        final repository = FakeCheckOutRepository(sessions: _sessions(7));
        final cubit = DashboardCubit(repository, activeLot: () => lot);
        await cubit.load();

        lot = 2;
        repository.listError = const NetworkFailure('offline');
        await cubit.load();

        expect(cubit.state, isA<DashboardFailure>());
      },
    );

    test('Security: the inside list plates come from the sessions, no vehicle download', () async {
      final cubit = DashboardCubit(
        FakeCheckOutRepository(sessions: _sessions(3)),
      );

      await cubit.load();

      final state = cubit.state as DashboardLoaded;
      expect(state.sessions.map(state.plateOf), ['PLT1', 'PLT2', 'PLT3']);
    });
  });
}
