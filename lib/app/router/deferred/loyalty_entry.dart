import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/loyalty/application/loyalty_admin_cubit.dart';
import '../../../features/loyalty/presentation/loyalty_page.dart';
import '../../di/injection.dart';

/// Deferred entry point for the admin loyalty screen.
Widget buildLoyaltyEntry() => BlocProvider<LoyaltyAdminCubit>(
  create: (_) => serviceLocator<LoyaltyAdminCubit>(),
  child: const LoyaltyPage(),
);
