import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/centered_scrollable.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/plate_input_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../application/public_feedback_cubit.dart';
import '../domain/entities/feedback_invite.dart';

/// Public, plate-keyed survey opened by the link/QR on the check-out receipt.
/// No login: the link carries the session and the plate is the access key.
class PublicFeedbackPage extends StatefulWidget {
  const PublicFeedbackPage({super.key, this.sessionId, this.plate});

  final int? sessionId;
  final String? plate;

  @override
  State<PublicFeedbackPage> createState() => _PublicFeedbackPageState();
}

class _PublicFeedbackPageState extends State<PublicFeedbackPage> {
  final _plate = TextEditingController();
  final _comment = TextEditingController();
  String? _key;
  int _rating = 0;

  bool get _sessionInvalid => (widget.sessionId ?? 0) <= 0;

  @override
  void initState() {
    super.initState();
    _key = widget.plate;
    if (_sessionInvalid || (_key ?? '').trim().isEmpty) {
      if (_sessionInvalid) {
        unawaited(_load());
      }
      return;
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _plate.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() => context.read<PublicFeedbackCubit>().load(
    sessionId: widget.sessionId,
    plate: _key,
  );

  void _unlock() {
    final plate = _plate.text.trim().toUpperCase();
    if (plate.isEmpty) {
      return;
    }
    setState(() => _key = plate);
    unawaited(_load());
  }

  void _submit() => unawaited(
    context.read<PublicFeedbackCubit>().submit(
      rating: _rating,
      comment: _comment.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedbackTitle)),
      body: SafeArea(
        child: BlocBuilder<PublicFeedbackCubit, PublicFeedbackState>(
          builder: (context, state) {
            if (!_sessionInvalid && (_key ?? '').trim().isEmpty) {
              return _PlateGate(controller: _plate, onUnlock: _unlock);
            }
            return switch (state) {
              FeedbackLoading() => const SkeletonCardList(itemCount: 3),
              FeedbackInvalidLink() => EmptyState(
                icon: Icons.link_off,
                title: l10n.feedbackInvalidTitle,
                message: l10n.feedbackInvalidBody,
              ),
              FeedbackFailure(:final failure) => ErrorState(
                message: l10n.failure(failure),
                onRetry: () => unawaited(_load()),
              ),
              FeedbackNotRateable(:final invite) => _Notice(
                icon: Icons.schedule,
                title: l10n.feedbackPendingTitle,
                message: l10n.feedbackPendingBody,
                lotName: invite.lotName,
              ),
              FeedbackAlready(:final rating) => _Thanks(
                title: l10n.feedbackAlreadyTitle,
                message: l10n.feedbackAlreadyBody,
                rating: rating,
              ),
              FeedbackSubmitted(:final rating) => _Thanks(
                title: l10n.feedbackThanksTitle,
                message: l10n.feedbackThanksBody,
                rating: rating,
              ),
              FeedbackReady(:final invite, :final submitting, :final failure) =>
                _Survey(
                  invite: invite,
                  submitting: submitting,
                  failure: failure,
                  rating: _rating,
                  comment: _comment,
                  onRate: (value) => setState(() => _rating = value),
                  onSubmit: _submit,
                ),
            };
          },
        ),
      ),
    );
  }
}

class _PlateGate extends StatelessWidget {
  const _PlateGate({required this.controller, required this.onUnlock});

  final TextEditingController controller;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.reviews_outlined,
                        size: Space.xl,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    l10n.feedbackGateTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    l10n.feedbackGateHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  PlateInputField(
                    key: const Key('feedback_plate'),
                    controller: controller,
                    autofocus: true,
                    onSubmitted: (_) => onUnlock(),
                  ),
                  const SizedBox(height: Space.md),
                  FilledButton.icon(
                    onPressed: onUnlock,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(l10n.feedbackUnlock),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Survey extends StatelessWidget {
  const _Survey({
    required this.invite,
    required this.submitting,
    required this.failure,
    required this.rating,
    required this.comment,
    required this.onRate,
    required this.onSubmit,
  });

  final FeedbackInvite invite;
  final bool submitting;
  final Failure? failure;
  final int rating;
  final TextEditingController comment;
  final ValueChanged<int> onRate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxForm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(invite: invite),
              const SizedBox(height: Space.md),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.feedbackRateLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      _StarPicker(
                        rating: rating,
                        onRate: submitting ? null : onRate,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        rating == 0 ? '' : _ratingLabel(l10n, rating),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      TextField(
                        key: const Key('feedback_comment'),
                        controller: comment,
                        enabled: !submitting,
                        maxLength: 500,
                        maxLines: 4,
                        minLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l10n.feedbackCommentLabel,
                          hintText: l10n.feedbackCommentHint,
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: Space.xl),
                            child: Icon(Icons.chat_bubble_outline),
                          ),
                        ),
                      ),
                      if (failure != null) ...[
                        const SizedBox(height: Space.sm),
                        _InlineError(message: l10n.failure(failure!)),
                      ],
                      const SizedBox(height: Space.md),
                      FilledButton.icon(
                        key: const Key('feedback-submit'),
                        onPressed: rating == 0 || submitting ? null : onSubmit,
                        icon: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(l10n.feedbackSubmit),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ratingLabel(AppLocalizations l10n, int value) => switch (value) {
    1 => l10n.feedbackRating1,
    2 => l10n.feedbackRating2,
    3 => l10n.feedbackRating3,
    4 => l10n.feedbackRating4,
    _ => l10n.feedbackRating5,
  };
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.rating, required this.onRate});

  final int rating;
  final ValueChanged<int>? onRate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var value = 1; value <= 5; value++)
          IconButton(
            key: Key('feedback-star-$value'),
            tooltip: l10n.feedbackStarLabel(value),
            onPressed: onRate == null ? null : () => onRate!(value),
            iconSize: 34,
            icon: Icon(
              value <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: value <= rating ? status.warning : scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.invite});

  final FeedbackInvite invite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sentiment_satisfied_alt,
              color: scheme.onPrimaryContainer,
              size: Space.lg,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.feedbackHeroTitle(invite.lotName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  l10n.feedbackHeroSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thanks extends StatelessWidget {
  const _Thanks({required this.title, required this.message, this.rating});

  final String title;
  final String message;
  final int? rating;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    return CenteredScrollable(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: status.success.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_outline,
            size: 40,
            color: status.success,
          ),
        ),
        const SizedBox(height: Space.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (rating != null) ...[
          const SizedBox(height: Space.md),
          Semantics(
            label: l10n.feedbackStarLabel(rating!),
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var value = 1; value <= 5; value++)
                    Icon(
                      value <= rating!
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: value <= rating! ? status.warning : scheme.outline,
                      size: 30,
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Space.lg),
        Text(
          l10n.feedbackCloseHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    required this.lotName,
  });

  final IconData icon;
  final String title;
  final String message;
  final String lotName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CenteredScrollable(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: Space.xl, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Space.md),
        if (lotName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Text(
              lotName,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
