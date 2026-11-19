import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/devices/application/devices_cubit.dart';
import '../../../features/devices/domain/repositories/device_repository.dart';
import '../../../features/devices/infrastructure/device_remote_data_source.dart';

void registerDevicesModule(GetIt sl) {
  sl
    ..registerLazySingleton<DeviceRemoteDataSource>(
      () => SupabaseDeviceRemoteDataSource(
        (name, params) => sl<SupabaseClient>().rpc(name, params: params),
      ),
    )
    ..registerLazySingleton<DeviceRepository>(
      () => DeviceRepositoryImpl(sl<DeviceRemoteDataSource>()),
    )
    ..registerFactory<DevicesCubit>(
      () => DevicesCubit(sl<DeviceRepository>()),
    );
}
