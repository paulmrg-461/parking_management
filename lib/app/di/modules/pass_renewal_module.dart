import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/pass_renewal/application/pass_renewal_cubit.dart';
import '../../../features/pass_renewal/domain/repositories/pass_renewal_repository.dart';
import '../../../features/pass_renewal/infrastructure/pass_renewal_remote_data_source.dart';
import '../../../features/pass_renewal/infrastructure/pass_renewal_repository_impl.dart';

void registerPassRenewalModule(GetIt sl) {
  sl
    ..registerLazySingleton<PassRenewalRemoteDataSource>(
      () => SupabasePassRenewalRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<PassRenewalRepository>(
      () => PassRenewalRepositoryImpl(sl<PassRenewalRemoteDataSource>()),
    )
    ..registerFactory<PassRenewalCubit>(
      () => PassRenewalCubit(sl<PassRenewalRepository>()),
    );
}
