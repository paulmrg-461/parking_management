import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../core/sync/sync_outbox.dart';
import '../../../features/check_out/application/check_out_cubit.dart';
import '../../../features/check_out/application/check_out_vehicle.dart';
import '../../../features/check_out/domain/repositories/check_out_repository.dart';
import '../../../features/check_out/infrastructure/check_out_remote_data_source.dart';
import '../../../features/check_out/infrastructure/check_out_repository_impl.dart';
import '../../../features/home/application/dashboard_cubit.dart';
import '../../../features/vehicles/domain/repositories/vehicle_repository.dart';

void registerCheckOutModule(GetIt sl) {
  sl
    ..registerLazySingleton<CheckOutRemoteDataSource>(
      () => DioCheckOutRemoteDataSource(sl<Dio>()),
    )
    ..registerLazySingleton<CheckOutRepository>(
      () => CheckOutRepositoryImpl(
        sl<CheckOutRemoteDataSource>(),
        sl<SyncOutbox>(),
      ),
    )
    ..registerLazySingleton<CheckOutVehicle>(
      () => CheckOutVehicle(sl<CheckOutRepository>()),
    )
    ..registerFactory<DashboardCubit>(
      () => DashboardCubit(sl<CheckOutRepository>()),
    )
    ..registerFactory<CheckOutCubit>(
      () => CheckOutCubit(
        sl<CheckOutVehicle>(),
        sl<CheckOutRepository>(),
        sl<VehicleRepository>(),
      ),
    );
}
