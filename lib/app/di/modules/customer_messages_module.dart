import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/customer_messages/domain/repositories/customer_message_repository.dart';
import '../../../features/customer_messages/infrastructure/customer_message_remote_data_source.dart';
import '../../../features/customer_messages/infrastructure/customer_message_repository_impl.dart';

void registerCustomerMessagesModule(GetIt sl) {
  sl
    ..registerLazySingleton<CustomerMessageRemoteDataSource>(
      () => SupabaseCustomerMessageRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<CustomerMessageRepository>(
      () => CustomerMessageRepositoryImpl(
        sl<CustomerMessageRemoteDataSource>(),
      ),
    );
}
