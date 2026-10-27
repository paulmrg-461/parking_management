import 'package:get_it/get_it.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/connectivity_cubit.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/hive_key_value_store.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/session_cache_cleaner.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/sync/sync_outbox.dart';

void registerCoreModule(GetIt sl, AppConfig config) {
  sl
    ..registerLazySingleton<AppConfig>(() => config)
    ..registerLazySingleton<KeyValueStore>(HiveKeyValueStore.new)
    ..registerLazySingleton<ThemeCubit>(
      () => ThemeCubit(sl<KeyValueStore>()),
    )
    ..registerLazySingleton<ConnectivityService>(ConnectivityPlusService.new)
    ..registerLazySingleton<ConnectivityCubit>(
      () => ConnectivityCubit(sl<ConnectivityService>()),
    )
    ..registerLazySingleton<SyncOutbox>(HiveSyncOutbox.new)
    ..registerLazySingleton<SessionCacheCleaner>(
      SessionCacheCleaner.new,
    );
}
