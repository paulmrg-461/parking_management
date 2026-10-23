import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/shifts/application/shift_cubit.dart';
import '../../../features/shifts/domain/repositories/shift_repository.dart';
import '../../../features/shifts/infrastructure/shift_remote_data_source.dart';
import '../../../features/shifts/infrastructure/shift_repository_impl.dart';

void registerShiftsModule(GetIt sl) {
  sl
    ..registerLazySingleton<ShiftRemoteDataSource>(
      () => SupabaseShiftRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<ShiftRepository>(
      () => ShiftRepositoryImpl(sl<ShiftRemoteDataSource>()),
    )
    ..registerFactory<ShiftCubit>(
      () => ShiftCubit(sl<ShiftRepository>()),
    );
}
