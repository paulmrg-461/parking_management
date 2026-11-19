import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/online_payments/application/online_payment_cubit.dart';
import '../../../features/online_payments/domain/repositories/online_payment_repository.dart';
import '../../../features/online_payments/infrastructure/online_payment_remote_data_source.dart';
import '../../../features/online_payments/infrastructure/online_payment_repository_impl.dart';

void registerOnlinePaymentsModule(GetIt sl) {
  sl
    ..registerLazySingleton<OnlinePaymentRemoteDataSource>(
      () => SupabaseOnlinePaymentRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<OnlinePaymentRepository>(
      () => OnlinePaymentRepositoryImpl(sl<OnlinePaymentRemoteDataSource>()),
    )
    ..registerFactory<OnlinePaymentCubit>(
      () => OnlinePaymentCubit(sl<OnlinePaymentRepository>()),
    );
}
