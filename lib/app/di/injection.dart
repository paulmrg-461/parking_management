import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../core/config/app_config.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/hive_key_value_store.dart';
import '../../core/storage/key_value_store.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/infrastructure/auth_local_data_source.dart';
import '../../features/auth/infrastructure/auth_remote_data_source.dart';
import '../../features/auth/infrastructure/auth_repository_impl.dart';
import '../../features/categories/application/categories_cubit.dart';
import '../../features/categories/domain/repositories/category_repository.dart';
import '../../features/categories/infrastructure/category_local_data_source.dart';
import '../../features/categories/infrastructure/category_remote_data_source.dart';
import '../../features/categories/infrastructure/category_repository_impl.dart';
import '../../features/check_in/application/check_in_cubit.dart';
import '../../features/check_in/domain/repositories/check_in_repository.dart';
import '../../features/check_in/infrastructure/check_in_remote_data_source.dart';
import '../../features/check_in/infrastructure/check_in_repository_impl.dart';
import '../../features/check_out/application/check_out_cubit.dart';
import '../../features/check_out/domain/repositories/check_out_repository.dart';
import '../../features/check_out/infrastructure/check_out_remote_data_source.dart';
import '../../features/check_out/infrastructure/check_out_repository_impl.dart';
import '../../features/monthly_passes/application/monthly_passes_cubit.dart';
import '../../features/monthly_passes/domain/repositories/monthly_pass_repository.dart';
import '../../features/monthly_passes/infrastructure/monthly_pass_local_data_source.dart';
import '../../features/monthly_passes/infrastructure/monthly_pass_remote_data_source.dart';
import '../../features/monthly_passes/infrastructure/monthly_pass_repository_impl.dart';
import '../../features/plate_scanning/application/plate_scanning_cubit.dart';
import '../../features/plate_scanning/domain/repositories/plate_scanner.dart';
import '../../features/plate_scanning/infrastructure/mlkit_plate_scanner.dart';
import '../../features/reports/application/reports_cubit.dart';
import '../../features/reports/domain/repositories/report_repository.dart';
import '../../features/reports/infrastructure/report_remote_data_source.dart';
import '../../features/reports/infrastructure/report_repository_impl.dart';
import '../../features/tariffs/application/tariffs_cubit.dart';
import '../../features/tariffs/domain/repositories/tariff_repository.dart';
import '../../features/tariffs/infrastructure/tariff_local_data_source.dart';
import '../../features/tariffs/infrastructure/tariff_remote_data_source.dart';
import '../../features/tariffs/infrastructure/tariff_repository_impl.dart';
import '../../features/users/application/users_cubit.dart';
import '../../features/vehicles/application/vehicles_cubit.dart';
import '../../features/vehicles/domain/repositories/vehicle_repository.dart';
import '../../features/vehicles/infrastructure/vehicle_local_data_source.dart';
import '../../features/vehicles/infrastructure/vehicle_remote_data_source.dart';
import '../../features/vehicles/infrastructure/vehicle_repository_impl.dart';

final GetIt serviceLocator = GetIt.instance;

Future<void> configureDependencies() async {
  final config = AppConfig.fromEnvironment();

  serviceLocator
    ..registerLazySingleton<AppConfig>(() => config)
    ..registerLazySingleton<DioClient>(() => DioClient(config.apiBaseUrl))
    ..registerLazySingleton<Dio>(() => serviceLocator<DioClient>().dio)
    ..registerLazySingleton<KeyValueStore>(() => HiveKeyValueStore())
    ..registerLazySingleton<AuthLocalDataSource>(() => HiveAuthLocalDataSource())
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => DioAuthRemoteDataSource(serviceLocator<Dio>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        serviceLocator<AuthRemoteDataSource>(),
        serviceLocator<AuthLocalDataSource>(),
      ),
    )
    ..registerLazySingleton<AuthCubit>(
      () => AuthCubit(serviceLocator<AuthRepository>()),
    )
    ..registerFactory<UsersCubit>(
      () => UsersCubit(serviceLocator<AuthRepository>()),
    )
    ..registerLazySingleton<CategoryLocalDataSource>(
      () => HiveCategoryLocalDataSource(),
    )
    ..registerLazySingleton<CategoryRemoteDataSource>(
      () => DioCategoryRemoteDataSource(serviceLocator<Dio>()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(
        serviceLocator<AuthRepository>(),
        serviceLocator<CategoryRemoteDataSource>(),
        serviceLocator<CategoryLocalDataSource>(),
      ),
    )
    ..registerFactory<CategoriesCubit>(
      () => CategoriesCubit(serviceLocator<CategoryRepository>()),
    )
    ..registerLazySingleton<TariffLocalDataSource>(
      () => HiveTariffLocalDataSource(),
    )
    ..registerLazySingleton<TariffRemoteDataSource>(
      () => DioTariffRemoteDataSource(serviceLocator<Dio>()),
    )
    ..registerLazySingleton<TariffRepository>(
      () => TariffRepositoryImpl(
        serviceLocator<AuthRepository>(),
        serviceLocator<TariffRemoteDataSource>(),
        serviceLocator<TariffLocalDataSource>(),
      ),
    )
    ..registerFactory<TariffsCubit>(
      () => TariffsCubit(serviceLocator<TariffRepository>()),
    )
    ..registerLazySingleton<VehicleLocalDataSource>(
      () => HiveVehicleLocalDataSource(),
    )
    ..registerLazySingleton<VehicleRemoteDataSource>(
      () => DioVehicleRemoteDataSource(serviceLocator<Dio>()),
    )
    ..registerLazySingleton<VehicleRepository>(
      () => VehicleRepositoryImpl(
        serviceLocator<AuthRepository>(),
        serviceLocator<VehicleRemoteDataSource>(),
        serviceLocator<VehicleLocalDataSource>(),
      ),
    )
    ..registerFactory<VehiclesCubit>(
      () => VehiclesCubit(serviceLocator<VehicleRepository>()),
    )
    ..registerLazySingleton<PlateScanner>(() => MlKitPlateScanner())
    ..registerFactory<PlateScanningCubit>(
      () => PlateScanningCubit(serviceLocator<PlateScanner>()),
    )
    ..registerLazySingleton<CheckInRemoteDataSource>(
      () => DioCheckInRemoteDataSource(serviceLocator<Dio>()),
    )
    ..registerLazySingleton<CheckInRepository>(
      () => CheckInRepositoryImpl(
        serviceLocator<AuthRepository>(),
        serviceLocator<CheckInRemoteDataSource>(),
      ),
    )
    ..registerFactory<CheckInCubit>(
      () => CheckInCubit(serviceLocator<CheckInRepository>()),
    )
    ..registerLazySingleton<CheckOutRemoteDataSource>(
      () => DioCheckOutRemoteDataSource(serviceLocator<Dio>()),
    )
    ..registerLazySingleton<CheckOutRepository>(
      () => CheckOutRepositoryImpl(
        serviceLocator<AuthRepository>(),
        serviceLocator<CheckOutRemoteDataSource>(),
      ),
    )
    ..registerFactory<CheckOutCubit>(
      () => CheckOutCubit(serviceLocator<CheckOutRepository>()),
    )
    ..registerLazySingleton<MonthlyPassLocalDataSource>(
      () => HiveMonthlyPassLocalDataSource(),
    )
    ..registerLazySingleton<MonthlyPassRemoteDataSource>(
      () => DioMonthlyPassRemoteDataSource(serviceLocator<Dio>()),
    )
    ..registerLazySingleton<MonthlyPassRepository>(
      () => MonthlyPassRepositoryImpl(
        serviceLocator<AuthRepository>(),
        serviceLocator<MonthlyPassRemoteDataSource>(),
        serviceLocator<MonthlyPassLocalDataSource>(),
      ),
    )
    ..registerFactory<MonthlyPassesCubit>(
      () => MonthlyPassesCubit(serviceLocator<MonthlyPassRepository>()),
    )
    ..registerLazySingleton<ReportRemoteDataSource>(
      () => DioReportRemoteDataSource(serviceLocator<Dio>()),
    )
    ..registerLazySingleton<ReportRepository>(
      () => ReportRepositoryImpl(
        serviceLocator<AuthRepository>(),
        serviceLocator<ReportRemoteDataSource>(),
      ),
    )
    ..registerFactory<ReportsCubit>(
      () => ReportsCubit(serviceLocator<ReportRepository>()),
    );

  await serviceLocator<KeyValueStore>().init();
}
