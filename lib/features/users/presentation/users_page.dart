import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/submission_listener.dart';
import '../../auth/domain/entities/user.dart';
import '../application/users_cubit.dart';
import 'create_user_dialog.dart';
import 'role_labels.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<UsersCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UsersCubit>();
    return ListPageScaffold(
      title: context.l10n.usersTitle,
      addTooltip: context.l10n.userAddTooltip,
      onAdd: () => unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => CreateUserDialog(onCreate: cubit.create),
        ),
      ),
      onRefresh: cubit.load,
      body: SubmissionListener<UsersCubit, UsersState>(
        submissionOf: _submissionOf,
        child: BlocBuilder<UsersCubit, UsersState>(
          buildWhen: (previous, current) =>
              previous is! UsersLoaded ||
              current is! UsersLoaded ||
              previous.users != current.users,
          builder: (context, state) => AsyncView<List<User>>(
            status: _status(context, state),
            builder: (users) => ListView.separated(
              padding: const EdgeInsets.only(bottom: Space.xxl * 2),
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _UserTile(user: users[index]),
            ),
          ),
        ),
      ),
    );
  }

  AsyncStatus<List<User>> _status(BuildContext context, UsersState state) =>
      switch (state) {
        UsersInitial() || UsersLoading() => const AsyncLoading(),
        UsersFailure(:final message, :final failure) => AsyncFailed(
          context.l10n.errorText(message, failure),
          context.read<UsersCubit>().load,
        ),
        UsersLoaded(:final users) when users.isEmpty => AsyncEmpty(
          context.l10n.usersEmpty,
          icon: Icons.people_outline,
        ),
        UsersLoaded(:final users) => AsyncReady(users),
      };

  static Submission? _submissionOf(UsersState state) =>
      state is UsersLoaded ? state.submission : null;
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(user.displayName),
      subtitle: Text('${user.username} · ${user.role.label(l10n)}'),
      trailing: Semantics(
        label: l10n.userActiveLabel(user.displayName),
        child: Switch(
          value: user.isActive,
          onChanged: (_) => _toggle(context),
        ),
      ),
    );
  }

  /// Deactivation is reversible, so it gets an undo instead of a dialog.
  void _toggle(BuildContext context) {
    final cubit = context.read<UsersCubit>();
    unawaited(cubit.toggleActive(user));
    if (user.isActive) {
      final toggled = User(
        id: user.id,
        username: user.username,
        displayName: user.displayName,
        role: user.role,
        isActive: false,
      );
      showUndoSnack(
        context,
        message: context.l10n.userDeactivated(user.displayName),
        onUndo: () => cubit.toggleActive(toggled),
      );
    }
  }
}
