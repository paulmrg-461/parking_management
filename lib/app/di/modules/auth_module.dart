import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/session_reader.dart';
import '../../../features/auth/application/auth_cubit.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/infrastructure/auth_local_data_source.dart';
import '../../../features/auth/infrastructure/auth_remote_data_source.dart';
import '../../../features/auth/infrastructure/auth_repository_impl.dart';
import '../../../features/auth/infrastructure/caching_auth_local_data_source.dart';

void registerAuthModule(GetIt sl) {
  sl
    ..registerLazySingleton<CachingAuthLocalDataSource>(
      () => CachingAuthLocalDataSource(HiveAuthLocalDataSource()),
    )
    // One cached instance serves both the repository and the interceptor.
    ..registerLazySingleton<AuthLocalDataSource>(
      () => sl<CachingAuthLocalDataSource>(),
    )
    ..registerLazySingleton<SessionReader>(
      () => sl<CachingAuthLocalDataSource>(),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => DioAuthRemoteDataSource(sl<Dio>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        sl<AuthRemoteDataSource>(),
        sl<AuthLocalDataSource>(),
      ),
    )
    ..registerLazySingleton<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));
}
