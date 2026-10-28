import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/records/application/records_cubit.dart';
import '../../../features/records/domain/repositories/record_repository.dart';
import '../../../features/records/infrastructure/record_remote_data_source.dart';
import '../../../features/records/infrastructure/record_repository_impl.dart';

void registerRecordsModule(GetIt sl) {
  sl
    ..registerLazySingleton<RecordRemoteDataSource>(
      () => SupabaseRecordRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<RecordRepository>(
      () => RecordRepositoryImpl(sl<RecordRemoteDataSource>()),
    )
    ..registerFactory<RecordsCubit>(() => RecordsCubit(sl<RecordRepository>()));
}
