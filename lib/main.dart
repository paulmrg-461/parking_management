import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

import 'app/app.dart';
import 'app/di/hive_registrar.g.dart';
import 'app/di/injection.dart';
import 'features/auth/application/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Hive.registerAdapters();
  await configureDependencies();
  final authCubit = serviceLocator<AuthCubit>();
  await authCubit.restore();
  runApp(ParkingApp(authCubit: authCubit));
}
