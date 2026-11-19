import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../auth/domain/entities/user.dart';
import '../../categories/application/categories_cubit.dart';
import '../../categories/domain/entities/category.dart';
import '../../users/application/users_cubit.dart';
import '../application/lpr_settings_cubit.dart';
import '../domain/commands/lpr_settings_update.dart';
import '../domain/entities/lpr_settings.dart';

/// `/gate-settings`: assist/auto, the confidence/vote thresholds, the default
/// category and system operator, and each camera's direction. Admin only.
/// The three cubits are created here so the router stays free of their imports.
class GateSettingsPage extends StatelessWidget {
  const GateSettingsPage({
    super.key,
    this.settingsCubit,
    this.categoriesCubit,
    this.usersCubit,
  });

  /// Test seams; the router leaves them null and the locator provides them.
  final LprSettingsCubit? settingsCubit;
  final CategoriesCubit? categoriesCubit;
  final UsersCubit? usersCubit;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider<LprSettingsCubit>(
        create: (_) => settingsCubit ?? serviceLocator<LprSettingsCubit>(),
      ),
      BlocProvider<CategoriesCubit>(
        create: (_) => categoriesCubit ?? serviceLocator<CategoriesCubit>(),
      ),
      BlocProvider<UsersCubit>(
        create: (_) => usersCubit ?? serviceLocator<UsersCubit>(),
      ),
    ],
    child: const _GateSettingsView(),
  );
}

class _GateSettingsView extends StatefulWidget {
  const _GateSettingsView();

  @override
  State<_GateSettingsView> createState() => _GateSettingsViewState();
}

class _GateSettingsViewState extends State<_GateSettingsView> {
  @override
  void initState() {
    super.initState();
    context.read<LprSettingsCubit>().load();
    context.read<CategoriesCubit>().load();
    context.read<UsersCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gateSettingsTitle)),
      body: BlocConsumer<LprSettingsCubit, LprSettingsState>(
        listenWhen: (_, current) => _submissionOf(current) is! SubmissionIdle,
        listener: (context, state) {
          final submission = _submissionOf(state);
          if (submission is SubmissionFailed) {
            showErrorSnack(
              context,
              context.l10n.errorText(submission.message, submission.failure),
            );
          } else if (submission is SubmissionSucceeded) {
            showInfoSnack(context, l10n.gateSaved);
          }
        },
        builder: (context, state) => switch (state) {
          LprSettingsLoading() => const _SettingsSkeleton(),
          LprSettingsFailure(:final failure) => ErrorState(
            message: l10n.failure(failure),
            onRetry: () => context.read<LprSettingsCubit>().load(),
          ),
          LprSettingsNoCameras() => EmptyState(
            icon: Icons.videocam_off_outlined,
            title: l10n.gateNoCamerasTitle,
            message: l10n.gateNoCamerasBody,
            action: FilledButton.icon(
              onPressed: () => context.go('/devices'),
              icon: const Icon(Icons.devices_other_outlined),
              label: Text(l10n.gateGoToDevices),
            ),
          ),
          LprSettingsLoaded(:final settings, :final submission) => _SettingsForm(
            key: ValueKey(settings),
            settings: settings,
            busy: submission.isInProgress,
            categories: _categories(context),
            users: _users(context),
          ),
        },
      ),
    );
  }

  Submission _submissionOf(LprSettingsState state) => switch (state) {
    LprSettingsLoaded(:final submission) => submission,
    LprSettingsNoCameras(:final submission) => submission,
    _ => const SubmissionIdle(),
  };

  List<Category> _categories(BuildContext context) =>
      switch (context.watch<CategoriesCubit>().state) {
        CategoriesLoaded(:final categories) => categories,
        _ => const [],
      };

  List<User> _users(BuildContext context) =>
      switch (context.watch<UsersCubit>().state) {
        UsersLoaded(:final users) =>
          [for (final user in users) if (user.isActive) user],
        _ => const [],
      };
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({
    super.key,
    required this.settings,
    required this.busy,
    required this.categories,
    required this.users,
  });

  final LprSettings settings;
  final bool busy;
  final List<Category> categories;
  final List<User> users;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late LprMode _mode = widget.settings.mode;
  late double _minConfidence = widget.settings.minConfidence;
  late double _autoConfidence = widget.settings.autoConfidence;
  late int _minVotes = widget.settings.minVotes;
  late int _voteWindow = widget.settings.voteWindowSeconds;
  late int _cooldown = widget.settings.cooldownSeconds;
  late int? _categoryId = widget.settings.defaultCategoryId;
  late int? _actingUserId = widget.settings.actingUserId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        Text(l10n.gateModeLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: Space.sm),
        SegmentedButton<LprMode>(
          segments: [
            ButtonSegment(
              value: LprMode.assist,
              label: Text(l10n.gateModeAssistShort),
            ),
            ButtonSegment(
              value: LprMode.auto,
              label: Text(l10n.gateModeAutoShort),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: widget.busy ? null : _selectMode,
        ),
        const SizedBox(height: Space.xs),
        Text(
          _mode == LprMode.auto ? l10n.gateModeAuto : l10n.gateModeAssist,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Space.md),
        _ConfidenceSlider(
          label: l10n.gateMinConfidence,
          value: _minConfidence,
          min: 0.5,
          max: 0.99,
          divisions: 49,
          onChanged: widget.busy ? null : (value) => setState(() {
            _minConfidence = value;
            if (_autoConfidence < value) _autoConfidence = value;
          }),
        ),
        _ConfidenceSlider(
          label: l10n.gateAutoConfidence,
          value: _autoConfidence,
          min: 0.5,
          max: 0.999,
          divisions: 499,
          onChanged: widget.busy ? null : (value) => setState(() {
            _autoConfidence = value < _minConfidence ? _minConfidence : value;
          }),
        ),
        _NumberStepper(
          label: l10n.gateMinVotes,
          value: _minVotes,
          min: 1,
          max: 10,
          onChanged: widget.busy ? null : (value) => setState(() => _minVotes = value),
        ),
        _NumberStepper(
          label: l10n.gateVoteWindow,
          value: _voteWindow,
          min: 2,
          max: 60,
          onChanged: widget.busy ? null : (value) => setState(() => _voteWindow = value),
        ),
        _NumberStepper(
          label: l10n.gateCooldown,
          value: _cooldown,
          min: 10,
          max: 3600,
          step: 10,
          onChanged: widget.busy ? null : (value) => setState(() => _cooldown = value),
        ),
        const SizedBox(height: Space.sm),
        DropdownButtonFormField<int>(
          initialValue: _categoryId,
          decoration: InputDecoration(labelText: l10n.gateDefaultCategory),
          items: [
            DropdownMenuItem<int>(value: null, child: Text(l10n.gateSelectOption)),
            for (final category in widget.categories)
              if (category.id case final id?)
                DropdownMenuItem(value: id, child: Text(category.name)),
          ],
          onChanged: widget.busy
              ? null
              : (value) => setState(() => _categoryId = value),
        ),
        const SizedBox(height: Space.sm),
        DropdownButtonFormField<int>(
          initialValue: _actingUserId,
          decoration: InputDecoration(labelText: l10n.gateActingUser),
          items: [
            DropdownMenuItem<int>(value: null, child: Text(l10n.gateSelectOption)),
            for (final user in widget.users)
              if (user.id case final id?)
                DropdownMenuItem(value: id, child: Text(user.displayName)),
          ],
          onChanged: widget.busy
              ? null
              : (value) => setState(() => _actingUserId = value),
        ),
        const SizedBox(height: Space.md),
        Text(l10n.gateCameraDirection, style: theme.textTheme.titleMedium),
        const SizedBox(height: Space.xs),
        for (final camera in widget.settings.cameras)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              children: [
                Expanded(child: Text(camera.name)),
                DropdownButton<String>(
                  value: camera.direction,
                  hint: Text(l10n.gateDirectionMissing),
                  items: [
                    DropdownMenuItem(
                      value: 'entry',
                      child: Text(l10n.gateDirectionEntry),
                    ),
                    DropdownMenuItem(
                      value: 'exit',
                      child: Text(l10n.gateDirectionExit),
                    ),
                  ],
                  onChanged: widget.busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          context.read<LprSettingsCubit>().setDirection(
                            camera.deviceId,
                            value,
                          );
                        },
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.md),
        FilledButton.icon(
          key: const Key('gate_settings_save'),
          onPressed: widget.busy ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(l10n.gateSave),
        ),
      ],
    );
  }

  Future<void> _selectMode(Set<LprMode> selection) async {
    final next = selection.first;
    if (next == LprMode.auto && _mode != LprMode.auto) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('gate_mode_confirm'),
          content: Text(context.l10n.gateModeAutoConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.gateDismiss),
            ),
            FilledButton(
              key: const Key('gate_mode_confirm_yes'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.gateModeAuto),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _mode = next);
  }

  void _save() {
    context.read<LprSettingsCubit>().save(
      LprSettingsUpdate(
        mode: _mode,
        minConfidence: _minConfidence,
        autoConfidence: _autoConfidence,
        minVotes: _minVotes,
        voteWindowSeconds: _voteWindow,
        cooldownSeconds: _cooldown,
        defaultCategoryId: _categoryId,
        actingUserId: _actingUserId,
      ),
    );
  }
}

class _ConfidenceSlider extends StatelessWidget {
  const _ConfidenceSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${(value * 100).toStringAsFixed(1)}%'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${(value * 100).toStringAsFixed(1)}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: '−',
          onPressed: change == null || value <= min
              ? null
              : () => change(value - step < min ? min : value - step),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 48,
          child: Text('$value', textAlign: TextAlign.center),
        ),
        IconButton(
          tooltip: '+',
          onPressed: change == null || value >= max
              ? null
              : () => change(value + step > max ? max : value + step),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: const [
          SkeletonBox(width: 120),
          SizedBox(height: Space.sm),
          SkeletonBox(height: 48),
          SizedBox(height: Space.md),
          SkeletonBox(height: 48),
          SizedBox(height: Space.md),
          SkeletonBox(height: 48),
        ],
      ),
    );
  }
}
