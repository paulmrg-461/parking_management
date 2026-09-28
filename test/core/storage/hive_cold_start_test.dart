import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_cold_start');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('HiveAuthLocalDataSource', () {
    test(
      'Success: session saved before a restart is restored on cold start',
      () async {
        await HiveAuthLocalDataSource().saveSession(_session);
        await _coldStart();

        expect(await HiveAuthLocalDataSource().readSession(), _session);
      },
    );

    test('Failure: cold start with no stored session returns null', () async {
      expect(await HiveAuthLocalDataSource().readSession(), isNull);
    });

    test(
      'Security: a cleared session is not resurrected after a restart',
      () async {
        final source = HiveAuthLocalDataSource();
        await source.saveSession(_session);
        await source.clearSession();
        await _coldStart();

        expect(await HiveAuthLocalDataSource().readSession(), isNull);
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
        await HiveCategoryLocalDataSource().cacheAll([category]);
        await HiveTariffLocalDataSource().cacheAll([tariff]);
        await HiveMonthlyPassLocalDataSource().cacheAll([pass]);
        await _coldStart();

        expect(await HiveVehicleLocalDataSource().readAll(), [vehicle]);
        expect(await HiveCategoryLocalDataSource().readAll(), [category]);
        expect(await HiveTariffLocalDataSource().readAll(), [tariff]);
        expect(await HiveMonthlyPassLocalDataSource().readAll(), [pass]);
      },
    );

    test('Failure: empty caches read as empty lists, not errors', () async {
      expect(await HiveVehicleLocalDataSource().readAll(), isEmpty);
      expect(await HiveCategoryLocalDataSource().readAll(), isEmpty);
    });
  });
}
