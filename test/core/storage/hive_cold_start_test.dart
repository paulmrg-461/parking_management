import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/lot/lot_session.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/auth/infrastructure/auth_local_data_source.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/infrastructure/category_local_data_source.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_local_data_source.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_local_data_source.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_local_data_source.dart';

import '../../helpers/fake_token_store.dart';

const _session = AuthSession(
  user: User(id: 1, username: 'ana', displayName: 'Ana', role: UserRole.admin),
  token: 'jwt-1',
);

/// Simulates an app restart: every box is closed, so nothing is open yet
/// when the next data source instance reads.
Future<void> _coldStart() => Hive.close();

void main() {
  late Directory dir;

  setUpAll(() => Hive.registerAdapters());

  late FakeTokenStore tokens;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_cold_start');
    Hive.init(dir.path);
    tokens = FakeTokenStore();
  });

  HiveAuthLocalDataSource authSource() => HiveAuthLocalDataSource(tokens);

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('HiveAuthLocalDataSource', () {
    test(
      'Success: session saved before a restart is restored on cold start',
      () async {
        await authSource().saveSession(_session);
        await _coldStart();

        expect(await authSource().readSession(), _session);
      },
    );

    test('Failure: cold start with no stored session returns null', () async {
      expect(await authSource().readSession(), isNull);
    });

    test(
      'Security: a cleared session is not resurrected after a restart',
      () async {
        final source = authSource();
        await source.saveSession(_session);
        await source.clearSession();
        await _coldStart();

        expect(await authSource().readSession(), isNull);
      },
    );
  });

  group('offline caches survive a cold start', () {
    test(
      'Success: vehicles, categories, tariffs and passes are readable',
      () async {
        const vehicle = Vehicle(id: 1, plate: 'ABC123', categoryId: 2);
        const category = Category(id: 2, name: 'Car');
        const tariff = Tariff(
          id: 3,
          categoryId: 2,
          type: TariffType.hourly,
          amount: 1,
        );
        final pass = MonthlyPass(
          id: 4,
          vehicleId: 1,
          startDate: DateTime(2026),
          endDate: DateTime(2026, 2),
          amount: 10,
        );
        await HiveVehicleLocalDataSource().cacheAll([vehicle]);
        await HiveCategoryLocalDataSource(LotSession()).cacheAll([category]);
        await HiveTariffLocalDataSource(LotSession()).cacheAll([tariff]);
        await HiveMonthlyPassLocalDataSource(LotSession()).cacheAll([pass]);
        await _coldStart();

        expect(await HiveVehicleLocalDataSource().readAll(), [vehicle]);
        expect(await HiveCategoryLocalDataSource(LotSession()).readAll(), [category]);
        expect(await HiveTariffLocalDataSource(LotSession()).readAll(), [tariff]);
        expect(await HiveMonthlyPassLocalDataSource(LotSession()).readAll(), [pass]);
      },
    );

    test('Failure: empty caches read as empty lists, not errors', () async {
      expect(await HiveVehicleLocalDataSource().readAll(), isEmpty);
      expect(await HiveCategoryLocalDataSource(LotSession()).readAll(), isEmpty);
    });
  });

  group('lot-scoped reference-data caches', () {
    test('Security: categories, tariffs and passes never mix lots', () async {
      final session = LotSession()..select(1);
      final categories = HiveCategoryLocalDataSource(session);
      final tariffs = HiveTariffLocalDataSource(session);
      final passes = HiveMonthlyPassLocalDataSource(session);

      await categories.cacheAll(const [Category(id: 1, name: 'Car')]);
      await tariffs.cacheAll(const [
        Tariff(
          id: 1,
          categoryId: 1,
          type: TariffType.hourly,
          amount: 5000,
        ),
      ]);
      await passes.cacheAll([
        MonthlyPass(
          id: 1,
          vehicleId: 1,
          startDate: DateTime(2026),
          endDate: DateTime(2026, 2),
          amount: 80000,
        ),
      ]);

      session.select(2);
      expect(await categories.readAll(), isEmpty);
      expect(await tariffs.readAll(), isEmpty);
      expect(await passes.readAll(), isEmpty);

      await categories.cacheAll(const [Category(id: 9, name: 'Bus')]);
      expect((await categories.readAll()).single.name, 'Bus');

      session.select(1);
      expect((await categories.readAll()).single.name, 'Car');
      expect((await tariffs.readAll()).single.amount, 5000);
      expect((await passes.readAll()).single.amount, 80000);

      // Switching back to lot 2 still has its own rows.
      session.select(2);
      expect((await categories.readAll()).single.name, 'Bus');
    });
  });
}
