import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

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
      HiveParkingSettingsLocalDataSource.new,
    )
    ..registerLazySingleton<ParkingSettingsRemoteDataSource>(
      () => DioParkingSettingsRemoteDataSource(sl<Dio>()),
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
