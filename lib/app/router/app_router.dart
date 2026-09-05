import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/categories/application/categories_cubit.dart';
import '../../features/check_in/application/check_in_cubit.dart';
import '../../features/check_in/presentation/check_in_page.dart';
import '../../features/check_out/application/check_out_cubit.dart';
import '../../features/check_out/presentation/check_out_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/plate_scanning/application/plate_scanning_cubit.dart';
import '../../features/plate_scanning/presentation/plate_scan_page.dart';
import '../../features/tariffs/application/tariffs_cubit.dart';
import '../../features/tariffs/presentation/tariffs_page.dart';
import '../../features/users/application/users_cubit.dart';
import '../../features/users/presentation/users_page.dart';
import '../../features/vehicles/application/vehicles_cubit.dart';
import '../../features/vehicles/presentation/vehicles_page.dart';
import '../di/injection.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final authState = context.read<AuthCubit>().state;
    final isAuthenticated = authState is AuthAuthenticated;
    final isLoginRoute = state.matchedLocation == '/login';

    if (!isAuthenticated && !isLoginRoute) {
      return '/login';
    }
    if (isAuthenticated && isLoginRoute) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => BlocProvider<UsersCubit>(
        create: (_) => serviceLocator<UsersCubit>(),
        child: const UsersPage(),
      ),
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => BlocProvider<CategoriesCubit>(
        create: (_) => serviceLocator<CategoriesCubit>(),
        child: const CategoriesPage(),
      ),
    ),
    GoRoute(
      path: '/tariffs',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<TariffsCubit>(
            create: (_) => serviceLocator<TariffsCubit>(),
          ),
          BlocProvider<CategoriesCubit>(
            create: (_) => serviceLocator<CategoriesCubit>(),
          ),
        ],
        child: const TariffsPage(),
      ),
    ),
    GoRoute(
      path: '/vehicles',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<VehiclesCubit>(
            create: (_) => serviceLocator<VehiclesCubit>(),
          ),
          BlocProvider<CategoriesCubit>(
            create: (_) => serviceLocator<CategoriesCubit>(),
          ),
        ],
        child: const VehiclesPage(),
      ),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => BlocProvider<PlateScanningCubit>(
        create: (_) => serviceLocator<PlateScanningCubit>(),
        child: const PlateScanPage(),
      ),
    ),
    GoRoute(
      path: '/check-in',
      builder: (context, state) => BlocProvider<CheckInCubit>(
        create: (_) => serviceLocator<CheckInCubit>(),
        child: const CheckInPage(),
      ),
    ),
    GoRoute(
      path: '/check-out',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<CheckOutCubit>(
            create: (_) => serviceLocator<CheckOutCubit>(),
          ),
          BlocProvider<VehiclesCubit>(
            create: (_) => serviceLocator<VehiclesCubit>(),
          ),
        ],
        child: const CheckOutPage(),
      ),
    ),
  ],
);
