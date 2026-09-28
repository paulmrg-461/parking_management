import 'package:get_it/get_it.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/sync/pending_photo_storage.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/sync/sync_status_cubit.dart';
import '../../../features/categories/infrastructure/category_local_data_source.dart';
import '../../../features/categories/infrastructure/category_mutation_replayer.dart';
import '../../../features/categories/infrastructure/category_remote_data_source.dart';
import '../../../features/check_in/infrastructure/check_in_mutation_replayer.dart';
import '../../../features/check_in/infrastructure/check_in_remote_data_source.dart';
import '../../../features/check_out/infrastructure/check_out_mutation_replayer.dart';
import '../../../features/check_out/infrastructure/check_out_remote_data_source.dart';
import '../../../features/tariffs/infrastructure/tariff_local_data_source.dart';
import '../../../features/tariffs/infrastructure/tariff_mutation_replayer.dart';
import '../../../features/tariffs/infrastructure/tariff_remote_data_source.dart';
import '../../../features/vehicles/infrastructure/vehicle_local_data_source.dart';
import '../../../features/vehicles/infrastructure/vehicle_mutation_replayer.dart';
import '../../../features/vehicles/infrastructure/vehicle_remote_data_source.dart';

/// Outbox drain + badge. Collects one replayer per queued entity type from
/// the feature data sources registered by the feature modules.
void registerSyncModule(GetIt sl) {
  sl
    ..registerLazySingleton<SyncService>(
      () => SyncService(sl<SyncOutbox>(), sl<ConnectivityService>(), [
        VehicleMutationReplayer(
          sl<VehicleRemoteDataSource>(),
          sl<VehicleLocalDataSource>(),
        ),
        TariffMutationReplayer(
          sl<TariffRemoteDataSource>(),
          sl<TariffLocalDataSource>(),
        ),
        CategoryMutationReplayer(
          sl<CategoryRemoteDataSource>(),
          sl<CategoryLocalDataSource>(),
        ),
        CheckInMutationReplayer(
          sl<CheckInRemoteDataSource>(),
          sl<PendingPhotoStorage>(),
        ),
        CheckOutMutationReplayer(sl<CheckOutRemoteDataSource>()),
      ]),
    )
    ..registerLazySingleton<SyncStatusCubit>(
      () => SyncStatusCubit(sl<SyncOutbox>(), sl<SyncService>().discard),
    );
}
