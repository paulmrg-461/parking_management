import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/notifications/application/notifications_cubit.dart';
import '../../../features/notifications/domain/repositories/notification_repository.dart';
import '../../../features/notifications/infrastructure/notification_local_data_source.dart';
import '../../../features/notifications/infrastructure/notification_remote_data_source.dart';
import '../../../features/notifications/infrastructure/notification_repository_impl.dart';
import '../../../features/notifications/infrastructure/push_service.dart';
import '../../../core/config/app_config.dart';

void registerNotificationsModule(GetIt sl) {
  sl
    ..registerLazySingleton<NotificationLocalDataSource>(
      HiveNotificationLocalDataSource.new,
    )
    ..registerLazySingleton<NotificationRemoteDataSource>(
      () => SupabaseNotificationRemoteDataSource(sl<SupabaseClient>()),
    )
    ..registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(
        sl<NotificationRemoteDataSource>(),
        sl<NotificationLocalDataSource>(),
      ),
    )
    ..registerFactory<NotificationsCubit>(
      () => NotificationsCubit(sl<NotificationRepository>()),
    )
    ..registerLazySingleton<PushService>(
      () => sl<AppConfig>().fcmEnabled
          ? FcmPushService(sl<NotificationRepository>(), sl<AppConfig>())
          : const NoopPushService(),
    );
}
