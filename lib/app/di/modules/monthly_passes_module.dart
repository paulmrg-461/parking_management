import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../features/monthly_passes/application/monthly_passes_cubit.dart';
import '../../../features/monthly_passes/domain/repositories/monthly_pass_repository.dart';
import '../../../features/monthly_passes/infrastructure/monthly_pass_local_data_source.dart';
import '../../../features/monthly_passes/infrastructure/monthly_pass_remote_data_source.dart';
import '../../../features/monthly_passes/infrastructure/monthly_pass_repository_impl.dart';
import '../../../features/vehicles/domain/repositories/vehicle_repository.dart';

void registerMonthlyPassesModule(GetIt sl) {
  sl
    ..registerLazySingleton<MonthlyPassLocalDataSource>(
      HiveMonthlyPassLocalDataSource.new,
    )
    ..registerLazySingleton<MonthlyPassRemoteDataSource>(
      () => DioMonthlyPassRemoteDataSource(sl<Dio>()),
    )
    ..registerLazySingleton<MonthlyPassRepository>(
      () => MonthlyPassRepositoryImpl(
        sl<MonthlyPassRemoteDataSource>(),
        sl<MonthlyPassLocalDataSource>(),
      ),
    )
    ..registerFactory<MonthlyPassesCubit>(
      () => MonthlyPassesCubit(
        sl<MonthlyPassRepository>(),
        sl<VehicleRepository>(),
      ),
    );
}
