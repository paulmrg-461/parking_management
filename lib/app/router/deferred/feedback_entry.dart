import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/feedback/application/feedback_summary_cubit.dart';
import '../../../features/feedback/presentation/feedback_summary_page.dart';
import '../../di/injection.dart';

/// Deferred entry point for the admin satisfaction report.
Widget buildFeedbackEntry() => BlocProvider<FeedbackSummaryCubit>(
  create: (_) => serviceLocator<FeedbackSummaryCubit>(),
  child: const FeedbackSummaryPage(),
);
