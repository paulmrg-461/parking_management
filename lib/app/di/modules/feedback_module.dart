import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/feedback/application/feedback_summary_cubit.dart';
import '../../../features/feedback/application/public_feedback_cubit.dart';
import '../../../features/feedback/domain/repositories/feedback_repository.dart';
import '../../../features/feedback/infrastructure/feedback_remote_data_source.dart';
import '../../../features/feedback/infrastructure/feedback_repository_impl.dart';

void registerFeedbackModule(GetIt sl) {
  sl
    ..registerLazySingleton<FeedbackRemoteDataSource>(
      () => SupabaseFeedbackRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<FeedbackRepository>(
      () => FeedbackRepositoryImpl(sl<FeedbackRemoteDataSource>()),
    )
    ..registerFactory<PublicFeedbackCubit>(
      () => PublicFeedbackCubit(sl<FeedbackRepository>()),
    )
    ..registerFactory<FeedbackSummaryCubit>(
      () => FeedbackSummaryCubit(sl<FeedbackRepository>()),
    );
}
