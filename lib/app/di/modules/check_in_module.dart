import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../core/sync/pending_photo_storage.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../../features/categories/domain/repositories/category_repository.dart';
import '../../../features/check_in/application/check_in_cubit.dart';
import '../../../features/check_in/application/create_check_in.dart';
import '../../../features/check_in/application/vehicle_lookup_cubit.dart';
import '../../../features/check_in/domain/repositories/check_in_repository.dart';
import '../../../features/check_in/infrastructure/check_in_remote_data_source.dart';
import '../../../features/check_in/infrastructure/check_in_repository_impl.dart';
import '../../../features/vehicles/domain/repositories/vehicle_repository.dart';

void registerCheckInModule(GetIt sl) {
  sl
    ..registerLazySingleton<CheckInRemoteDataSource>(
      () => DioCheckInRemoteDataSource(sl<Dio>()),
    )
    ..registerLazySingleton<CheckInRepository>(
      () => CheckInRepositoryImpl(
        sl<CheckInRemoteDataSource>(),
        sl<SyncOutbox>(),
        sl<PendingPhotoStorage>(),
      ),
    )
    ..registerLazySingleton<CreateCheckIn>(
      () => CreateCheckIn(sl<CheckInRepository>()),
    )
    ..registerFactory<CheckInCubit>(
      () => CheckInCubit(sl<CreateCheckIn>(), sl<CheckInRepository>()),
    )
    ..registerFactory<VehicleLookupCubit>(
      () =>
          VehicleLookupCubit(sl<VehicleRepository>(), sl<CategoryRepository>()),
    );
}
