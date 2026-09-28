import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/failure_messages.dart';
import '../l10n/l10n.dart';
import '../state/submission.dart';
import 'submission_feedback.dart';

/// Reports action outcomes of cubit [B]: failures as a localized error
/// SnackBar (the list stays), successes through [onSuccess].
class SubmissionListener<B extends StateStreamable<S>, S>
    extends StatelessWidget {
  const SubmissionListener({
    super.key,
    required this.submissionOf,
    required this.child,
    this.onSuccess,
  });

  final Submission? Function(S state) submissionOf;
  final void Function(BuildContext context, Object? result)? onSuccess;
  final Widget child;

  bool _listenWhen(S previous, S current) {
    final before = submissionOf(previous);
    final after = submissionOf(current);
    return submissionJustFailed(before, after) ||
        (onSuccess != null && submissionJustSucceeded(before, after));
  }

  void _listener(BuildContext context, S state) {
    switch (submissionOf(state)) {
      case SubmissionFailed(:final message, :final failure):
        showErrorSnack(context, context.l10n.errorText(message, failure));
      case SubmissionSucceeded(:final result):
        onSuccess?.call(context, result);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<B, S>(
    listenWhen: _listenWhen,
    listener: _listener,
    child: child,
  );
}
