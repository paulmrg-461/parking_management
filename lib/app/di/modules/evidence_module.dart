import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/evidence/application/evidence_cubit.dart';
import '../../../features/evidence/domain/repositories/evidence_repository.dart';
import '../../../features/evidence/infrastructure/evidence_remote_data_source.dart';
import '../../../features/evidence/infrastructure/evidence_repository_impl.dart';

void registerEvidenceModule(GetIt sl) {
  sl
    ..registerLazySingleton<EvidenceRemoteDataSource>(
      () => SupabaseEvidenceRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<EvidenceRepository>(
      () => EvidenceRepositoryImpl(sl<EvidenceRemoteDataSource>()),
    )
    ..registerFactory<EvidenceCubit>(
      () => EvidenceCubit(sl<EvidenceRepository>()),
    );
}
