import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/pricing/application/price_quote_cubit.dart';
import '../../../features/pricing/application/pricing_cubit.dart';
import '../../../features/pricing/application/pricing_simulation_cubit.dart';
import '../../../features/pricing/domain/repositories/price_quote_repository.dart';
import '../../../features/pricing/domain/repositories/pricing_repository.dart';
import '../../../features/pricing/infrastructure/price_quote_remote_data_source.dart';
import '../../../features/pricing/infrastructure/pricing_remote_data_source.dart';
import '../../../features/pricing/infrastructure/pricing_repository_impl.dart';

void registerPricingModule(GetIt sl) {
  sl
    ..registerLazySingleton<PricingRemoteDataSource>(
      () => SupabasePricingRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<PriceQuoteRemoteDataSource>(
      () => SupabasePriceQuoteRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<PricingRepository>(
      () => PricingRepositoryImpl(sl<PricingRemoteDataSource>()),
    )
    ..registerLazySingleton<PriceQuoteRepository>(
      () => PriceQuoteRepositoryImpl(sl<PriceQuoteRemoteDataSource>()),
    )
    ..registerFactory<PricingCubit>(
      () => PricingCubit(sl<PricingRepository>()),
    )
    ..registerFactory<PricingSimulationCubit>(
      () => PricingSimulationCubit(sl<PricingRepository>()),
    )
    ..registerFactory<PriceQuoteCubit>(
      () => PriceQuoteCubit(sl<PriceQuoteRepository>()),
    );
}
