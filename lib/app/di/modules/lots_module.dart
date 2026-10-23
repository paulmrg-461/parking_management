import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/lot/lot_context.dart';
import '../../../core/lot/lot_session.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../features/lots/application/lots_cubit.dart';
import '../../../features/lots/domain/repositories/lots_repository.dart';
import '../../../features/lots/infrastructure/lots_remote_data_source.dart';
import '../../../features/lots/infrastructure/lots_repository_impl.dart';

void registerLotsModule(GetIt sl) {
  sl
    ..registerLazySingleton<LotSession>(LotSession.new)
    ..registerLazySingleton<LotContext>(
      () => LotContext(sl<KeyValueStore>(), sl<LotSession>()),
    )
    ..registerLazySingleton<LotsRemoteDataSource>(
      () => SupabaseLotsRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<LotsRepository>(
      () => LotsRepositoryImpl(sl<LotsRemoteDataSource>()),
    )
    ..registerLazySingleton<LotsCubit>(
      () => LotsCubit(sl<LotsRepository>(), sl<LotContext>()),
    );
}
