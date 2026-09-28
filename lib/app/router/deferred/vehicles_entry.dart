import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/vehicles/application/vehicles_cubit.dart';
import '../../../features/vehicles/presentation/vehicles_page.dart';
import '../../di/injection.dart';

/// Deferred entry point (loaded on demand; admin-only).
Widget buildVehiclesEntry() => BlocProvider<VehiclesCubit>(
  create: (_) => serviceLocator<VehiclesCubit>(),
  child: const VehiclesPage(),
);
