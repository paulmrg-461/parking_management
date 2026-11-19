import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/loyalty/application/loyalty_admin_cubit.dart';
import '../../../features/loyalty/application/loyalty_status_cubit.dart';
import '../../../features/loyalty/domain/repositories/loyalty_repository.dart';
import '../../../features/loyalty/infrastructure/loyalty_remote_data_source.dart';
import '../../../features/loyalty/infrastructure/loyalty_repository_impl.dart';

/// Loyalty rewards: the operator chip and the admin screen. Online only.
void registerLoyaltyModule(GetIt sl) {
  sl
    ..registerLazySingleton<LoyaltyRemoteDataSource>(
      () => SupabaseLoyaltyRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<LoyaltyRepository>(
      () => LoyaltyRepositoryImpl(sl<LoyaltyRemoteDataSource>()),
    )
    ..registerFactory<LoyaltyStatusCubit>(
      () => LoyaltyStatusCubit(sl<LoyaltyRepository>()),
    )
    ..registerFactory<LoyaltyAdminCubit>(
      () => LoyaltyAdminCubit(sl<LoyaltyRepository>()),
    );
}
