import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../features/users/application/users_cubit.dart';
import '../../../features/users/domain/repositories/user_repository.dart';
import '../../../features/users/infrastructure/user_remote_data_source.dart';
import '../../../features/users/infrastructure/user_repository_impl.dart';

void registerUsersModule(GetIt sl) {
  sl
    ..registerLazySingleton<UserRemoteDataSource>(
      () => DioUserRemoteDataSource(sl<Dio>()),
    )
    ..registerLazySingleton<UserRepository>(
      () => UserRepositoryImpl(sl<UserRemoteDataSource>()),
    )
    ..registerFactory<UsersCubit>(() => UsersCubit(sl<UserRepository>()));
}
