import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';

import '../../../features/reports/application/reports_cubit.dart';
import '../../../features/reports/domain/repositories/report_repository.dart';
import '../../../features/reports/infrastructure/report_remote_data_source.dart';
import '../../../features/reports/infrastructure/report_repository_impl.dart';

void registerReportsModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReportRemoteDataSource>(
      () => SupabaseReportRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<ReportRepository>(
      () => ReportRepositoryImpl(sl<ReportRemoteDataSource>()),
    )
    ..registerFactory<ReportsCubit>(() => ReportsCubit(sl<ReportRepository>()));
}
