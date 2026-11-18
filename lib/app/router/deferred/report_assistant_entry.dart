import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/report_assistant/application/report_assistant_cubit.dart';
import '../../../features/report_assistant/presentation/report_assistant_page.dart';
import '../../di/injection.dart';

/// Deferred entry point for the admin report assistant.
Widget buildReportAssistantEntry() => BlocProvider<ReportAssistantCubit>(
  create: (_) => serviceLocator<ReportAssistantCubit>()..load(),
  child: const ReportAssistantPage(),
);
