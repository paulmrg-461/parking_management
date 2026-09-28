import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../core/sync/sync_outbox.dart';
import '../../../features/categories/domain/repositories/category_repository.dart';
import '../../../features/vehicles/application/vehicles_cubit.dart';
import '../../../features/vehicles/domain/repositories/vehicle_repository.dart';
import '../../../features/vehicles/infrastructure/vehicle_local_data_source.dart';
import '../../../features/vehicles/infrastructure/vehicle_remote_data_source.dart';
import '../../../features/vehicles/infrastructure/vehicle_repository_impl.dart';

void registerVehiclesModule(GetIt sl) {
  sl
    ..registerLazySingleton<VehicleLocalDataSource>(
      HiveVehicleLocalDataSource.new,
    )
    ..registerLazySingleton<VehicleRemoteDataSource>(
      () => DioVehicleRemoteDataSource(sl<Dio>()),
    )
    ..registerLazySingleton<VehicleRepository>(
      () => VehicleRepositoryImpl(
        sl<VehicleRemoteDataSource>(),
        sl<VehicleLocalDataSource>(),
        sl<SyncOutbox>(),
      ),
    )
    ..registerFactory<VehiclesCubit>(
      () => VehiclesCubit(sl<VehicleRepository>(), sl<CategoryRepository>()),
    );
}
