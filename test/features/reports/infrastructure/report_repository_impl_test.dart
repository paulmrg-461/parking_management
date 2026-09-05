import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/reports/domain/entities/occupancy_report.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/infrastructure/report_remote_data_source.dart';
import 'package:parking_management/features/reports/infrastructure/report_repository_impl.dart';

import '../../../helpers/fake_auth_repository.dart';

class _FakeRemote implements ReportRemoteDataSource {
  _FakeRemote({this.revenueToReturn, this.occupancyToReturn, this.error});

  final RevenueReport? revenueToReturn;
  final OccupancyReport? occupancyToReturn;
  final Failure? error;
  String? tokenUsed;

  @override
  Future<RevenueReport> getRevenueReport(
    String token, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    tokenUsed = token;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return revenueToReturn!;
  }

  @override
  Future<OccupancyReport> getOccupancyReport(String token) async {
    tokenUsed = token;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return occupancyToReturn!;
  }
}

void main() {
  final revenue = RevenueReport(
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 1, 31),
    total: 100000,
    byDay: [DailyRevenue(date: DateTime(2026, 1, 1), amount: 100000)],
    byCategory: const [
      CategoryRevenue(categoryId: 1, categoryName: 'Car', amount: 100000),
    ],
  );
  const occupancy = OccupancyReport(
    totalOpen: 5,
    byCategory: [
      CategoryOccupancy(categoryId: 1, categoryName: 'Car', count: 5),
    ],
  );

  AuthSession authenticatedSession() => const AuthSession(
        user: User(id: 1, username: 'admin', displayName: 'Admin', role: UserRole.admin),
        token: 'token-1',
      );

  test(
    'Success: both report getters return the remote-mapped entities',
    () async {
      final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
      final remote = _FakeRemote(
        revenueToReturn: revenue,
        occupancyToReturn: occupancy,
      );
      final repository = ReportRepositoryImpl(auth, remote);

      final revenueResult = await repository.getRevenueReport(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );
      final occupancyResult = await repository.getOccupancyReport();

      expect(revenueResult, revenue);
      expect(occupancyResult, occupancy);
      expect(remote.tokenUsed, 'token-1');
    },
  );

  test('Failure: remote errors are rethrown as the mapped Failure', () async {
    final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
    final remote = _FakeRemote(error: const NetworkFailure('offline'));
    final repository = ReportRepositoryImpl(auth, remote);

    expect(
      () => repository.getOccupancyReport(),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test(
    'Security: missing token throws AuthenticationFailure before any network call',
    () async {
      final auth = FakeAuthRepository();
      final remote = _FakeRemote(
        revenueToReturn: revenue,
        occupancyToReturn: occupancy,
      );
      final repository = ReportRepositoryImpl(auth, remote);

      expect(
        () => repository.getRevenueReport(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
        ),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(remote.tokenUsed, isNull);
    },
  );
}
