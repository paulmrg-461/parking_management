import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/damage_comparison/application/attach_exit_evidence.dart';
import '../../../features/damage_comparison/application/damage_comparison_cubit.dart';
import '../../../features/damage_comparison/domain/repositories/damage_comparison_repository.dart';
import '../../../features/damage_comparison/infrastructure/damage_comparison_remote_data_source.dart';
import '../../../features/damage_comparison/infrastructure/exit_evidence_remote_data_source.dart';

void registerDamageComparisonModule(GetIt sl) {
  sl
    ..registerLazySingleton<ExitEvidenceRemoteDataSource>(
      () => SupabaseExitEvidenceRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<AttachExitEvidence>(
      () => AttachExitEvidence(sl<ExitEvidenceRemoteDataSource>()),
    )
    ..registerLazySingleton<DamageComparisonRemoteDataSource>(
      () => SupabaseDamageComparisonRemoteDataSource(
        (name, body, {headers}) async {
          final response = await sl<SupabaseClient>().functions.invoke(
            name,
            body: body,
            headers: headers,
          );
          return response.data;
        },
        (name, params) => sl<SupabaseClient>().rpc(name, params: params),
      ),
    )
    ..registerLazySingleton<DamageComparisonRepository>(
      () => DamageComparisonRepositoryImpl(
        sl<DamageComparisonRemoteDataSource>(),
      ),
    )
    ..registerFactoryParam<DamageComparisonCubit, int, void>(
      (sessionId, _) => DamageComparisonCubit(
        sl<DamageComparisonRepository>(),
        sessionId: sessionId,
      ),
    );
}
