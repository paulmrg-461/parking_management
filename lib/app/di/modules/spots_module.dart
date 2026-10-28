import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/spots/application/spots_cubit.dart';
import '../../../features/spots/domain/repositories/spot_repository.dart';
import '../../../features/spots/infrastructure/spot_remote_data_source.dart';
import '../../../features/spots/infrastructure/spot_repository_impl.dart';

void registerSpotsModule(GetIt sl) {
  sl
    ..registerLazySingleton<SpotRemoteDataSource>(
      () => SupabaseSpotRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<SpotRepository>(
      () => SpotRepositoryImpl(sl<SpotRemoteDataSource>()),
    )
    ..registerFactory<SpotsCubit>(() => SpotsCubit(sl<SpotRepository>()));
}
