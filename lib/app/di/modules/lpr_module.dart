import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/lpr/application/lpr_inbox_cubit.dart';
import '../../../features/lpr/domain/repositories/lpr_repository.dart';
import '../../../features/lpr/infrastructure/lpr_remote_data_source.dart';

void registerLprModule(GetIt sl) {
  sl
    ..registerLazySingleton<LprRemoteDataSource>(
      () => SupabaseLprRemoteDataSource(
        (name, params) => sl<SupabaseClient>().rpc(name, params: params),
        (path) => sl<SupabaseClient>().storage.from('evidence').download(path),
      ),
    )
    ..registerLazySingleton<LprRepository>(
      () => LprRepositoryImpl(sl<LprRemoteDataSource>()),
    )
    ..registerFactory<LprInboxCubit>(
      () => LprInboxCubit(sl<LprRepository>()),
    );
}
