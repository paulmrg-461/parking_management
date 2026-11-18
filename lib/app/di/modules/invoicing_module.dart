import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/invoicing/application/invoicing_cubit.dart';
import '../../../features/invoicing/application/issue_fiscal_document.dart';
import '../../../features/invoicing/domain/repositories/invoicing_repository.dart';
import '../../../features/invoicing/infrastructure/invoicing_remote_data_source.dart';
import '../../../features/invoicing/infrastructure/invoicing_repository_impl.dart';

/// Electronic invoicing: the admin screen and the post-check-out issuance.
/// Online only, inert while the lot keeps `mode = 'off'`.
void registerInvoicingModule(GetIt sl) {
  sl
    ..registerLazySingleton<InvoicingRemoteDataSource>(
      () => SupabaseInvoicingRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<InvoicingRepository>(
      () => InvoicingRepositoryImpl(sl<InvoicingRemoteDataSource>()),
    )
    ..registerFactory<IssueFiscalDocument>(
      () => IssueFiscalDocument(sl<InvoicingRepository>()),
    )
    ..registerFactory<InvoicingCubit>(
      () => InvoicingCubit(sl<InvoicingRepository>()),
    );
}
