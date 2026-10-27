import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/categories/domain/repositories/category_repository.dart';
import '../../../features/reservations/application/reservations_cubit.dart';
import '../../../features/reservations/domain/repositories/reservation_repository.dart';
import '../../../features/reservations/infrastructure/reservation_remote_data_source.dart';
import '../../../features/reservations/infrastructure/reservation_repository_impl.dart';

void registerReservationsModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReservationRemoteDataSource>(
      () => SupabaseReservationRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<ReservationRepository>(
      () => ReservationRepositoryImpl(sl<ReservationRemoteDataSource>()),
    )
    ..registerFactory<ReservationsCubit>(
      () => ReservationsCubit(
        sl<ReservationRepository>(),
        sl<CategoryRepository>(),
      ),
    );
}
