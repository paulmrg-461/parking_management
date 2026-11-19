import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/public_booking/application/public_booking_cubit.dart';
import '../../../features/public_booking/domain/repositories/public_booking_repository.dart';
import '../../../features/public_booking/infrastructure/public_booking_remote_data_source.dart';
import '../../../features/public_booking/infrastructure/public_booking_repository_impl.dart';

void registerPublicBookingModule(GetIt sl) {
  sl
    ..registerLazySingleton<PublicBookingRemoteDataSource>(
      () => SupabasePublicBookingRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<PublicBookingRepository>(
      () => PublicBookingRepositoryImpl(sl<PublicBookingRemoteDataSource>()),
    )
    ..registerFactory<PublicBookingCubit>(
      () => PublicBookingCubit(sl<PublicBookingRepository>()),
    );
}
