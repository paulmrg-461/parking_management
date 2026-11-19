import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/merchants/application/merchant_settlement_cubit.dart';
import '../../../features/merchants/application/merchant_validation_cubit.dart';
import '../../../features/merchants/application/merchants_cubit.dart';
import '../../../features/merchants/domain/repositories/merchant_repository.dart';
import '../../../features/merchants/domain/repositories/public_merchant_repository.dart';
import '../../../features/merchants/infrastructure/merchant_remote_data_source.dart';
import '../../../features/merchants/infrastructure/merchant_repository_impl.dart';
import '../../../features/merchants/infrastructure/public_merchant_remote_data_source.dart';
import '../../../features/merchants/infrastructure/public_merchant_repository_impl.dart';

void registerMerchantsModule(GetIt sl) {
  sl
    ..registerLazySingleton<MerchantRemoteDataSource>(
      () => SupabaseMerchantRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<MerchantRepository>(
      () => MerchantRepositoryImpl(sl<MerchantRemoteDataSource>()),
    )
    ..registerLazySingleton<PublicMerchantRemoteDataSource>(
      () => SupabasePublicMerchantRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<PublicMerchantRepository>(
      () => PublicMerchantRepositoryImpl(
        sl<PublicMerchantRemoteDataSource>(),
      ),
    )
    ..registerFactory<MerchantsCubit>(
      () => MerchantsCubit(sl<MerchantRepository>()),
    )
    ..registerFactory<MerchantValidationCubit>(
      () => MerchantValidationCubit(sl<PublicMerchantRepository>()),
    )
    ..registerFactory<MerchantSettlementCubit>(
      () => MerchantSettlementCubit(sl<MerchantRepository>()),
    );
}
