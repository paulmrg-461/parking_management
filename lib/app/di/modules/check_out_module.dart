import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';

import '../../../core/lot/lot_session.dart';
import '../../../core/qr/qr_decoder.dart';
import '../../../core/storage/key_value_store.dart';

import '../../../core/sync/sync_outbox.dart';
import '../../../features/check_out/application/check_out_cubit.dart';
import '../../../features/check_out/application/check_out_vehicle.dart';
import '../../../features/check_out/domain/repositories/check_out_repository.dart';
import '../../../features/check_out/infrastructure/check_out_remote_data_source.dart';
import '../../../features/check_out/infrastructure/check_out_repository_impl.dart';
import '../../../features/home/application/dashboard_cubit.dart';
import '../../../features/home/domain/repositories/dashboard_cache.dart';
import '../../../features/home/infrastructure/hive_dashboard_cache.dart';

void registerCheckOutModule(GetIt sl) {
  sl
    ..registerLazySingleton<CheckOutRemoteDataSource>(
      () => SupabaseCheckOutRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<CheckOutRepository>(
      () => CheckOutRepositoryImpl(
        sl<CheckOutRemoteDataSource>(),
        sl<SyncOutbox>(),
        sl<LotSession>(),
      ),
    )
    ..registerLazySingleton<CheckOutVehicle>(
      () => CheckOutVehicle(sl<CheckOutRepository>()),
    )
    ..registerLazySingleton<DashboardCache>(
      () => HiveDashboardCache(sl<KeyValueStore>(), sl<LotSession>()),
    )
    ..registerFactory<DashboardCubit>(
      () => DashboardCubit(
        sl<CheckOutRepository>(),
        activeLot: () => sl<LotSession>().activeLotId,
        cache: sl<DashboardCache>(),
      ),
    )
    ..registerLazySingleton<QrDecoder>(ZxingQrDecoder.new)
    ..registerFactory<CheckOutCubit>(
      () => CheckOutCubit(sl<CheckOutVehicle>(), sl<CheckOutRepository>()),
    );
}
