import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../core/sync/sync_outbox.dart';
import '../../../features/categories/domain/repositories/category_repository.dart';
import '../../../features/tariffs/application/tariffs_cubit.dart';
import '../../../features/tariffs/domain/repositories/tariff_repository.dart';
import '../../../features/tariffs/infrastructure/tariff_local_data_source.dart';
import '../../../features/tariffs/infrastructure/tariff_remote_data_source.dart';
import '../../../features/tariffs/infrastructure/tariff_repository_impl.dart';

void registerTariffsModule(GetIt sl) {
  sl
    ..registerLazySingleton<TariffLocalDataSource>(
      HiveTariffLocalDataSource.new,
    )
    ..registerLazySingleton<TariffRemoteDataSource>(
      () => DioTariffRemoteDataSource(sl<Dio>()),
    )
    ..registerLazySingleton<TariffRepository>(
      () => TariffRepositoryImpl(
        sl<TariffRemoteDataSource>(),
        sl<TariffLocalDataSource>(),
        sl<SyncOutbox>(),
      ),
    )
    ..registerFactory<TariffsCubit>(
      () => TariffsCubit(sl<TariffRepository>(), sl<CategoryRepository>()),
    );
}
