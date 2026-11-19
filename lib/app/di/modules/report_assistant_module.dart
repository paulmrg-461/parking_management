import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/report_assistant/application/report_assistant_cubit.dart';
import '../../../features/report_assistant/domain/repositories/report_assistant_repository.dart';
import '../../../features/report_assistant/infrastructure/report_assistant_remote_data_source.dart';
import '../../../features/report_assistant/infrastructure/report_assistant_repository_impl.dart';

/// Natural-language answers over the report RPCs. Online only, admin only and
/// inert while the server has no AI key.
void registerReportAssistantModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReportAssistantRemoteDataSource>(
      () => SupabaseReportAssistantRemoteDataSource(
        (name, body, {headers}) async {
          final response = await sl<SupabaseClient>().functions.invoke(
            name,
            body: body,
            headers: headers,
          );
          return response.data;
        },
      ),
    )
    ..registerLazySingleton<ReportAssistantRepository>(
      () => ReportAssistantRepositoryImpl(
        sl<ReportAssistantRemoteDataSource>(),
      ),
    )
    ..registerFactory<ReportAssistantCubit>(
      () => ReportAssistantCubit(sl<ReportAssistantRepository>()),
    );
}
