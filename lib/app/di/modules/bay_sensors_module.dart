import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/bay_sensors/application/bay_sensors_cubit.dart';
import '../../../features/bay_sensors/domain/repositories/bay_repository.dart';
import '../../../features/bay_sensors/infrastructure/bay_remote_data_source.dart';

void registerBaySensorsModule(GetIt sl) {
  sl
    ..registerLazySingleton<BayRemoteDataSource>(
      () => SupabaseBayRemoteDataSource(
        (name, params) => sl<SupabaseClient>().rpc(name, params: params),
      ),
    )
    ..registerLazySingleton<BayRepository>(
      () => BayRepositoryImpl(sl<BayRemoteDataSource>()),
    )
    ..registerFactory<BaySensorsCubit>(
      () => BaySensorsCubit(sl<BayRepository>()),
    );
}
