import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/anomalies/application/anomalies_cubit.dart';
import '../../../features/anomalies/domain/repositories/anomaly_repository.dart';
import '../../../features/anomalies/infrastructure/anomaly_remote_data_source.dart';
import '../../../features/anomalies/infrastructure/anomaly_repository_impl.dart';

void registerAnomaliesModule(GetIt sl) {
  sl
    ..registerLazySingleton<AnomalyRemoteDataSource>(
      () => SupabaseAnomalyRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<AnomalyRepository>(
      () => AnomalyRepositoryImpl(sl<AnomalyRemoteDataSource>()),
    )
    ..registerFactory<AnomaliesCubit>(
      () => AnomaliesCubit(sl<AnomalyRepository>()),
    );
}
