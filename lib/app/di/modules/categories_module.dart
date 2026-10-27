import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';

import '../../../core/lot/lot_session.dart';

import '../../../core/sync/sync_outbox.dart';
import '../../../features/categories/application/categories_cubit.dart';
import '../../../features/categories/domain/repositories/category_repository.dart';
import '../../../features/categories/infrastructure/category_local_data_source.dart';
import '../../../features/categories/infrastructure/category_remote_data_source.dart';
import '../../../features/categories/infrastructure/category_repository_impl.dart';

void registerCategoriesModule(GetIt sl) {
  sl
    ..registerLazySingleton<CategoryLocalDataSource>(
      () => HiveCategoryLocalDataSource(sl<LotSession>()),
    )
    ..registerLazySingleton<CategoryRemoteDataSource>(
      () => SupabaseCategoryRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(
        sl<CategoryRemoteDataSource>(),
        sl<CategoryLocalDataSource>(),
        sl<SyncOutbox>(),
      ),
    )
    ..registerFactory<CategoriesCubit>(
      () => CategoriesCubit(sl<CategoryRepository>()),
    );
}
