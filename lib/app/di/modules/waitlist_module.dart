import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/waitlist/application/public_waitlist_cubit.dart';
import '../../../features/waitlist/application/waitlist_cubit.dart';
import '../../../features/waitlist/domain/repositories/public_waitlist_repository.dart';
import '../../../features/waitlist/domain/repositories/waitlist_repository.dart';
import '../../../features/waitlist/infrastructure/public_waitlist_remote_data_source.dart';
import '../../../features/waitlist/infrastructure/public_waitlist_repository_impl.dart';
import '../../../features/waitlist/infrastructure/waitlist_remote_data_source.dart';
import '../../../features/waitlist/infrastructure/waitlist_repository_impl.dart';

/// Booking waitlist: the desk list and the public card. Both are online only,
/// so nothing here touches the sync outbox.
void registerWaitlistModule(GetIt sl) {
  sl
    ..registerLazySingleton<WaitlistRemoteDataSource>(
      () => SupabaseWaitlistRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<PublicWaitlistRemoteDataSource>(
      () => SupabasePublicWaitlistRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<WaitlistRepository>(
      () => WaitlistRepositoryImpl(sl<WaitlistRemoteDataSource>()),
    )
    ..registerLazySingleton<PublicWaitlistRepository>(
      () => PublicWaitlistRepositoryImpl(sl<PublicWaitlistRemoteDataSource>()),
    )
    ..registerFactory<WaitlistCubit>(
      () => WaitlistCubit(sl<WaitlistRepository>()),
    )
    ..registerFactory<PublicWaitlistCubit>(
      () => PublicWaitlistCubit(sl<PublicWaitlistRepository>()),
    );
}
