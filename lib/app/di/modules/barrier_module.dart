import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/barrier/application/barrier_cubit.dart';
import '../../../features/barrier/domain/repositories/barrier_repository.dart';
import '../../../features/barrier/infrastructure/barrier_remote_data_source.dart';

void registerBarrierModule(GetIt sl) {
  sl
    ..registerLazySingleton<BarrierRemoteDataSource>(
      () => SupabaseBarrierRemoteDataSource(
        (name, params) => sl<SupabaseClient>().rpc(name, params: params),
      ),
    )
    ..registerLazySingleton<BarrierRepository>(
      () => BarrierRepositoryImpl(sl<BarrierRemoteDataSource>()),
    )
    ..registerFactory<BarrierCubit>(
      () => BarrierCubit(sl<BarrierRepository>()),
    );
}
