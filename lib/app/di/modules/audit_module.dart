import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/audit/application/audit_cubit.dart';
import '../../../features/audit/domain/repositories/audit_repository.dart';
import '../../../features/audit/infrastructure/audit_remote_data_source.dart';
import '../../../features/audit/infrastructure/audit_repository_impl.dart';

void registerAuditModule(GetIt sl) {
  sl
    ..registerLazySingleton<AuditRemoteDataSource>(
      () => SupabaseAuditRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<AuditRepository>(
      () => AuditRepositoryImpl(sl<AuditRemoteDataSource>()),
    )
    ..registerFactory<AuditCubit>(
      () => AuditCubit(sl<AuditRepository>()),
    );
}
