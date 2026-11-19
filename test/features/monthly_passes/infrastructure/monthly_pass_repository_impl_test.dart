import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/lot/lot_session.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass_payment.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/pass_renewal_offer_summary.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_local_data_source.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_remote_data_source.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_repository_impl.dart';

class _FakeRemote implements MonthlyPassRemoteDataSource {
  _FakeRemote({this.failWithNetwork = false});

  final bool failWithNetwork;
  int deleteCalls = 0;

  @override
  Future<List<MonthlyPass>> list({int? vehicleId}) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return [
      MonthlyPass(
        id: 1,
        vehicleId: 1,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        amount: 100000,
      ),
    ];
  }

  @override
  Future<MonthlyPass> create(Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<MonthlyPass> update(int id, Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls++;
  }

  @override
  Future<List<MonthlyPassPayment>> pendingPayments() async => const [];

  @override
  Future<MonthlyPassPayment> registerPayment(int id, String method) async =>
      throw UnimplementedError();

  Failure? linkError;

  @override
  Future<List<PassRenewalOfferSummary>> renewalOffers() async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return const [
      PassRenewalOfferSummary(monthlyPassId: 1, status: 'open'),
    ];
  }

  @override
  Future<bool> sendRenewalLink(int passId) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    final error = linkError;
    if (error != null) {
      throw error;
    }
    return true;
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('monthly_pass_repo_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  MonthlyPassRepositoryImpl repository(_FakeRemote remote) =>
      MonthlyPassRepositoryImpl(
        remote,
        HiveMonthlyPassLocalDataSource(LotSession()),
      );

  test('Success: list returns remote monthly passes and caches them', () async {
    final result = await repository(_FakeRemote()).list();

    expect(result.single.amount, 100000);
  });

  test(
    'Failure: list falls back to the local cache on network failure',
    () async {
      final local = HiveMonthlyPassLocalDataSource(LotSession());
      await MonthlyPassRepositoryImpl(_FakeRemote(), local).list();

      final offline = MonthlyPassRepositoryImpl(
        _FakeRemote(failWithNetwork: true),
        local,
      );

      expect((await offline.list()).single.amount, 100000);
    },
  );

  test('Security: list with no cached data and no network returns empty, never throws', () async {
    final repo = MonthlyPassRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      HiveMonthlyPassLocalDataSource(LotSession()),
    );

    expect(await repo.list(), isEmpty);
  });

  test('delete calls the remote data source', () async {
    final remote = _FakeRemote();
    final repo = repository(remote);

    await repo.delete(1);

    expect(remote.deleteCalls, 1);
  });

  test('Success: renewalOffers returns [] offline and never fails the list', () async {
    final repository = MonthlyPassRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      HiveMonthlyPassLocalDataSource(LotSession()),
    );

    expect(await repository.renewalOffers(), isEmpty);
  });

  test('Failure: sendRenewalLink offline throws NetworkFailure', () async {
    final repository = MonthlyPassRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      HiveMonthlyPassLocalDataSource(LotSession()),
    );

    await expectLater(
      repository.sendRenewalLink(1),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('Failure: sendRenewalLink maps the missing owner phone', () async {
    final remote = _FakeRemote()
      ..linkError = const ValidationFailure(
        'MissingOwnerPhoneError',
        'MissingOwnerPhoneError',
      );
    final repository = MonthlyPassRepositoryImpl(
      remote,
      HiveMonthlyPassLocalDataSource(LotSession()),
    );

    await expectLater(
      repository.sendRenewalLink(1),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'MissingOwnerPhoneError',
        ),
      ),
    );
  });

  test('Success: sendRenewalLink reports the queue result', () async {
    final repository = MonthlyPassRepositoryImpl(
      _FakeRemote(),
      HiveMonthlyPassLocalDataSource(LotSession()),
    );

    expect(await repository.sendRenewalLink(1), isTrue);
  });
}
