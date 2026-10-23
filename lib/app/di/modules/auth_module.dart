import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/session_cache_cleaner.dart';
import '../../../core/storage/token_store.dart';
import '../../../core/sync/sync_service.dart';
import '../../../features/auth/application/auth_cubit.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/infrastructure/auth_local_data_source.dart';
import '../../../features/auth/infrastructure/auth_remote_data_source.dart';
import '../../../features/auth/infrastructure/auth_repository_impl.dart';
import '../../../features/auth/infrastructure/caching_auth_local_data_source.dart';
import '../../../features/auth/infrastructure/supabase_auth_remote_data_source.dart';

void registerAuthModule(GetIt sl) {
  sl
    ..registerLazySingleton<TokenStore>(SecureTokenStore.new)
    ..registerLazySingleton<CachingAuthLocalDataSource>(
      () => CachingAuthLocalDataSource(
        HiveAuthLocalDataSource(sl<TokenStore>()),
      ),
    )
    // One cached instance serves both the repository and the interceptor.
    ..registerLazySingleton<AuthLocalDataSource>(
      () => sl<CachingAuthLocalDataSource>(),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => SupabaseAuthRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        sl<AuthRemoteDataSource>(),
        sl<AuthLocalDataSource>(),
        sl<SessionCacheCleaner>(),
        () => sl<SupabaseClient>().auth.signOut(scope: SignOutScope.local),
      ),
    )
    ..registerLazySingleton<AuthCubit>(
      () => AuthCubit(
        sl<AuthRepository>(),
        // Resolved on login to avoid a DI cycle through SyncService.
        () => sl<SyncService>().flush(),
      ),
    );
}
