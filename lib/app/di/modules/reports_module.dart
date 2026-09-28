import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../features/reports/application/reports_cubit.dart';
import '../../../features/reports/domain/repositories/report_repository.dart';
import '../../../features/reports/infrastructure/report_remote_data_source.dart';
import '../../../features/reports/infrastructure/report_repository_impl.dart';

void registerReportsModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReportRemoteDataSource>(
      () => DioReportRemoteDataSource(sl<Dio>()),
    )
    ..registerLazySingleton<ReportRepository>(
      () => ReportRepositoryImpl(sl<ReportRemoteDataSource>()),
    )
    ..registerFactory<ReportsCubit>(() => ReportsCubit(sl<ReportRepository>()));
}
