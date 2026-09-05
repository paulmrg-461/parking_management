import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_cubit.dart';
import 'router/app_router.dart';

class ParkingApp extends StatelessWidget {
  const ParkingApp({super.key, required this.authCubit});

  final AuthCubit authCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp.router(
        title: 'Parking Management',
        theme: AppTheme.light(),
        routerConfig: appRouter,
      ),
    );
  }
}
