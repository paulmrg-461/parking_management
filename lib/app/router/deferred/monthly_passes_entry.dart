import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/monthly_passes/application/monthly_passes_cubit.dart';
import '../../../features/monthly_passes/presentation/monthly_passes_page.dart';
import '../../di/injection.dart';

/// Deferred entry point (loaded on demand; admin-only).
Widget buildMonthlyPassesEntry() => BlocProvider<MonthlyPassesCubit>(
  create: (_) => serviceLocator<MonthlyPassesCubit>(),
  child: const MonthlyPassesPage(),
);
