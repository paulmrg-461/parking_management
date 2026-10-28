import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/policies/application/policies_cubit.dart';
import '../../../features/policies/domain/repositories/policy_repository.dart';
import '../../../features/policies/infrastructure/policy_remote_data_source.dart';
import '../../../features/policies/infrastructure/policy_repository_impl.dart';

void registerPoliciesModule(GetIt sl) {
  sl
    ..registerLazySingleton<PolicyRemoteDataSource>(
      () => SupabasePolicyRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<PolicyRepository>(
      () => PolicyRepositoryImpl(sl<PolicyRemoteDataSource>()),
    )
    ..registerFactory<PoliciesCubit>(
      () => PoliciesCubit(sl<PolicyRepository>()),
    );
}
