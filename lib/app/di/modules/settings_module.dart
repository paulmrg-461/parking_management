import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';

import '../../../core/lot/lot_session.dart';

import '../../../core/sync/sync_outbox.dart';
import '../../../features/settings/application/branding_cubit.dart';
import '../../../features/settings/application/settings_cubit.dart';
import '../../../features/settings/domain/repositories/parking_settings_repository.dart';
import '../../../features/settings/infrastructure/parking_settings_local_data_source.dart';
import '../../../features/settings/infrastructure/parking_settings_remote_data_source.dart';
import '../../../features/settings/infrastructure/parking_settings_repository_impl.dart';

void registerSettingsModule(GetIt sl) {
  sl
    ..registerLazySingleton<ParkingSettingsLocalDataSource>(
      () => HiveParkingSettingsLocalDataSource(sl<LotSession>()),
    )
    ..registerLazySingleton<ParkingSettingsRemoteDataSource>(
      () => SupabaseParkingSettingsRemoteDataSource(
        sl<SupabaseClient>(),
        sl<LotSession>(),
      ),
    )
    ..registerLazySingleton<ParkingSettingsRepository>(
      () => ParkingSettingsRepositoryImpl(
        sl<ParkingSettingsRemoteDataSource>(),
        sl<ParkingSettingsLocalDataSource>(),
        sl<SyncOutbox>(),
      ),
    )
    ..registerFactory<SettingsCubit>(
      () => SettingsCubit(sl<ParkingSettingsRepository>()),
    )
    // App-lifetime: shared by chrome, the WhatsApp action and contact page.
    ..registerLazySingleton<BrandingCubit>(
      () => BrandingCubit(sl<ParkingSettingsRepository>()),
    );
}
