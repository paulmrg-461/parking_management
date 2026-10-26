import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/vehicle_history/application/vehicle_history_cubit.dart';
import '../../../features/vehicle_history/domain/repositories/vehicle_history_repository.dart';
import '../../../features/vehicle_history/infrastructure/vehicle_history_local_data_source.dart';
import '../../../features/vehicle_history/infrastructure/vehicle_history_remote_data_source.dart';
import '../../../features/vehicle_history/infrastructure/vehicle_history_repository_impl.dart';

void registerVehicleHistoryModule(GetIt sl) {
  sl
    ..registerLazySingleton<VehicleHistoryLocalDataSource>(
      HiveVehicleHistoryLocalDataSource.new,
    )
    ..registerLazySingleton<VehicleHistoryRemoteDataSource>(
      () => SupabaseVehicleHistoryRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<VehicleHistoryRepository>(
      () => VehicleHistoryRepositoryImpl(
        sl<VehicleHistoryRemoteDataSource>(),
        sl<VehicleHistoryLocalDataSource>(),
      ),
    )
    ..registerFactory<VehicleHistoryCubit>(
      () => VehicleHistoryCubit(sl<VehicleHistoryRepository>()),
    );
}
