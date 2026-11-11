import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:parking_management/app/di/injection.dart';
import 'package:parking_management/app/di/modules/sync_module.dart';
import 'package:parking_management/app/di/modules/platform_module_io.dart'
    as io;
import 'package:parking_management/app/di/modules/platform_module_web.dart'
    as web;
import 'package:parking_management/core/config/app_config.dart';
import 'package:parking_management/core/sync/file_pending_photo_storage.dart';
import 'package:parking_management/core/sync/hive_pending_photo_storage.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/notifying_sync_outbox.dart';
import 'package:parking_management/core/sync/pending_photo_storage.dart';
import 'package:parking_management/core/sync/sync_outbox.dart';
import 'package:parking_management/core/sync/sync_service.dart';
import 'package:parking_management/features/check_in/application/check_in_cubit.dart';
import 'package:parking_management/features/check_out/application/check_out_cubit.dart';
import 'package:parking_management/features/monthly_passes/application/monthly_passes_cubit.dart';
import 'package:parking_management/features/plate_scanning/domain/repositories/plate_image_capture.dart';
import 'package:parking_management/features/plate_scanning/domain/repositories/plate_scanner.dart';
import 'package:parking_management/features/plate_scanning/infrastructure/manual_entry_plate_scanner.dart';
import 'package:parking_management/features/plate_scanning/infrastructure/mlkit_plate_scanner.dart';
import 'package:parking_management/features/reports/application/reports_cubit.dart';
import 'package:parking_management/features/tariffs/application/tariffs_cubit.dart';
import 'package:parking_management/features/users/application/users_cubit.dart';
import 'package:parking_management/features/vehicles/application/vehicles_cubit.dart';
import 'package:parking_management/features/waitlist/application/public_waitlist_cubit.dart';
import 'package:parking_management/features/waitlist/application/waitlist_cubit.dart';
import 'package:parking_management/features/waitlist/domain/repositories/public_waitlist_repository.dart';
import 'package:parking_management/features/waitlist/domain/repositories/waitlist_repository.dart';

const _config = AppConfig(
  appName: 'test',
  supabaseUrl: 'http://localhost:8000',
  supabaseAnonKey: 'test-anon-key',
);

void _register(GetIt sl) {
  sl.registerSingleton<SupabaseClient>(
    SupabaseClient(_config.supabaseUrl, _config.supabaseAnonKey),
  );
  registerAllModules(sl, _config);
}

void main() {
  late GetIt sl;

  setUp(() => sl = GetIt.asNewInstance());

  test(
    'Success: every module registers without duplicates and cubits resolve',
    () {
      _register(sl);

      expect(sl<UsersCubit>(), isA<UsersCubit>());
      expect(sl<VehiclesCubit>(), isA<VehiclesCubit>());
      expect(sl<TariffsCubit>(), isA<TariffsCubit>());
      expect(sl<MonthlyPassesCubit>(), isA<MonthlyPassesCubit>());
      expect(sl<ReportsCubit>(), isA<ReportsCubit>());
      expect(sl<CheckInCubit>(), isA<CheckInCubit>());
      expect(sl<CheckOutCubit>(), isA<CheckOutCubit>());
      expect(sl<SyncService>(), isA<SyncService>());
    },
  );

  test('Success: registers the waitlist module', () {
    _register(sl);

    expect(sl<WaitlistRepository>(), isA<WaitlistRepository>());
    expect(sl<PublicWaitlistRepository>(), isA<PublicWaitlistRepository>());
    expect(sl<WaitlistCubit>(), isA<WaitlistCubit>());
    expect(sl<PublicWaitlistCubit>(), isA<PublicWaitlistCubit>());
  });

  test('Success: the shared outbox kicks a drain on every enqueue', () {
    _register(sl);

    expect(sl<SyncOutbox>(), isA<NotifyingSyncOutbox>());
  });

  test('Success: every queued entity type has a registered replayer', () {
    _register(sl);

    final entities = buildMutationReplayers(sl)
        .map((replayer) => replayer.entity)
        .toSet();

    // SyncService throws StateError on replay for a missing entry, so the
    // replayer set must cover every queued entity exactly.
    expect(entities, MutationEntity.values.toSet());
  });

  test('Success: mobile platform module wires ML Kit and file photos', () {
    io.registerPlatformModule(sl);

    expect(sl<PlateScanner>(), isA<MlKitPlateScanner>());
    expect(sl<PlateScanner>().isSupported, isTrue);
    expect(sl<PendingPhotoStorage>(), isA<FilePendingPhotoStorage>());
    expect(sl.isRegistered<PlateImageCapture>(), isTrue);
  });

  test('Failure: web platform module has no OCR and keeps photos in Hive', () {
    web.registerPlatformModule(sl);

    expect(sl<PlateScanner>(), isA<ManualEntryPlateScanner>());
    expect(sl<PlateScanner>().isSupported, isFalse);
    expect(sl<PendingPhotoStorage>(), isA<HivePendingPhotoStorage>());
  });
}
