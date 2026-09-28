import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/reports/application/reports_cubit.dart';
import '../../../features/reports/presentation/reports_page.dart';
import '../../di/injection.dart';

/// Deferred entry point (loaded on demand; admin-only, pulls in charts).
Widget buildReportsEntry() => BlocProvider<ReportsCubit>(
  create: (_) => serviceLocator<ReportsCubit>(),
  child: const ReportsPage(),
);
