import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/observability/error_reporter.dart';
import '../../../core/observability/supabase_client_error_sink.dart';

void registerObservabilityModule(GetIt sl) {
  sl.registerLazySingleton<ErrorReporter>(
    () => ErrorReporter(SupabaseClientErrorSink(sl<SupabaseClient>())),
  );
}
