import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/pricing/application/pricing_cubit.dart';
import '../../../features/pricing/application/pricing_simulation_cubit.dart';
import '../../../features/pricing/presentation/pricing_page.dart';
import '../../di/injection.dart';

/// Deferred entry point for the admin dynamic-pricing screen.
Widget buildPricingEntry() => MultiBlocProvider(
  providers: [
    BlocProvider<PricingCubit>(create: (_) => serviceLocator<PricingCubit>()),
    BlocProvider<PricingSimulationCubit>(
      create: (_) => serviceLocator<PricingSimulationCubit>(),
    ),
  ],
  child: const PricingPage(),
);
