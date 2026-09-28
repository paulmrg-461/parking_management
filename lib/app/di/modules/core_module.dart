import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/connectivity_cubit.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/etag_cache_interceptor.dart';
import '../../../core/network/session_reader.dart';
import '../../../core/storage/hive_key_value_store.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../../features/auth/application/auth_cubit.dart';

void registerCoreModule(GetIt sl, AppConfig config) {
  sl
    ..registerLazySingleton<AppConfig>(() => config)
    // Conditional GETs for reference data that rarely changes.
    ..registerLazySingleton<EtagCacheInterceptor>(
      () => EtagCacheInterceptor(
        cacheablePaths: const {'/api/categories', '/api/tariffs'},
      ),
    )
    ..registerLazySingleton<DioClient>(
      () => DioClient(
        config.apiBaseUrl,
        interceptors: [
          AuthInterceptor(
            sl<SessionReader>(),
            // Resolved lazily: AuthCubit depends (indirectly) on Dio.
            () => sl<AuthCubit>().sessionExpired(),
          ),
          sl<EtagCacheInterceptor>(),
        ],
      ),
    )
    ..registerLazySingleton<Dio>(() => sl<DioClient>().dio)
    ..registerLazySingleton<KeyValueStore>(HiveKeyValueStore.new)
    ..registerLazySingleton<ConnectivityService>(ConnectivityPlusService.new)
    ..registerLazySingleton<ConnectivityCubit>(
      () => ConnectivityCubit(sl<ConnectivityService>()),
    )
    ..registerLazySingleton<SyncOutbox>(HiveSyncOutbox.new);
}
