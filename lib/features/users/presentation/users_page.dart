import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/submission_listener.dart';
import '../../auth/application/auth_cubit.dart';
import '../../lots/application/lots_cubit.dart';
import '../../lots/domain/entities/parking_lot.dart';
import '../../auth/domain/entities/user.dart';
import '../application/users_cubit.dart';
import 'create_user_dialog.dart';
import 'role_labels.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

enum _RoleFilter { all, admin, operator }

class _UsersPageState extends State<UsersPage> {
  _RoleFilter _filter = _RoleFilter.all;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<UsersCubit>().load());
  }

  /// The lot list only matters when the installation has more than one site.
  ({List<ParkingLot> lots, int? activeId}) _lotOptions(BuildContext context) {
    try {
      final state = context.read<LotsCubit>().state;
      if (state is LotsLoaded) {
        return (lots: state.lots, activeId: state.activeId);
      }
    } on ProviderNotFoundException {
      // Isolated tests do not provide the lot cubit.
    }
    return (lots: const [], activeId: null);
  }

  Future<void> _addUser(BuildContext context, UsersCubit cubit) async {
    final options = _lotOptions(context);
    await showDialog<void>(
      context: context,
      builder: (_) => CreateUserDialog(
        onCreate: cubit.create,
        lots: options.lots,
        initialLotId: options.activeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UsersCubit>();
    return ListPageScaffold(
      title: context.l10n.usersTitle,
      addTooltip: context.l10n.userAddTooltip,
      onAdd: () => unawaited(_addUser(context, cubit)),
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
            builder: (users) => _UsersList(
              users: users,
              filter: _filter,
              onFilter: (filter) => setState(() => _filter = filter),
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

class _UsersList extends StatelessWidget {
  const _UsersList({
    required this.users,
    required this.filter,
    required this.onFilter,
  });

  final List<User> users;
  final _RoleFilter filter;
  final ValueChanged<_RoleFilter> onFilter;

  List<User> get _visible => switch (filter) {
    _RoleFilter.all => users,
    _RoleFilter.admin => [
      for (final user in users)
        if (user.role == UserRole.admin) user,
    ],
    _RoleFilter.operator => [
      for (final user in users)
        if (user.role == UserRole.operator) user,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = _visible;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
          child: SegmentedButton<_RoleFilter>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _RoleFilter.all,
                label: Text(l10n.usersFilterAll),
              ),
              ButtonSegment(
                value: _RoleFilter.admin,
                label: Text(l10n.roleAdmin),
              ),
              ButtonSegment(
                value: _RoleFilter.operator,
                label: Text(l10n.roleOperator),
              ),
            ],
            selected: {filter},
            onSelectionChanged: (selection) => onFilter(selection.first),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? EmptyState(
                  message: l10n.usersFilterEmpty,
                  icon: Icons.filter_alt_off_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(
                    top: Space.sm,
                    bottom: Space.xxl * 2,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _UserTile(user: visible[index]),
                ),
        ),
      ],
    );
  }
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l10n.userActiveLabel(user.displayName),
            child: Switch(
              value: user.isActive,
              onChanged: (_) => _toggle(context),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.userActions,
            onSelected: (action) => _onAction(context, action),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'pin', child: Text(l10n.userResetPin)),
              if (!_isSelf(context))
                PopupMenuItem(value: 'delete', child: Text(l10n.userDelete)),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSelf(BuildContext context) {
    try {
      final auth = context.read<AuthCubit>();
      return switch (auth.state) {
        AuthAuthenticated(:final session) => session.user.id == user.id,
        _ => false,
      };
    } on ProviderNotFoundException {
      return false;
    }
  }

  void _onAction(BuildContext context, String action) {
    if (action == 'pin') {
      _resetPin(context);
    } else if (action == 'delete') {
      _delete(context);
    }
  }

  Future<void> _resetPin(BuildContext context) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPinDialog(displayName: user.displayName),
    );
    if (pin != null && context.mounted) {
      await context.read<UsersCubit>().resetPin(user, pin);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.userDeleteTitle,
        body: l10n.userDeleteBody(user.displayName),
        confirmLabel: l10n.actionDelete,
        destructive: true,
      ),
    );
    if (confirmed && context.mounted) {
      await context.read<UsersCubit>().delete(user);
    }
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

class _ResetPinDialog extends StatefulWidget {
  const _ResetPinDialog({required this.displayName});

  final String displayName;

  @override
  State<_ResetPinDialog> createState() => _ResetPinDialogState();
}

class _ResetPinDialogState extends State<_ResetPinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.userResetPinTitle(widget.displayName)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(labelText: l10n.userNewPin),
          validator: (value) =>
              (value ?? '').trim().length == 6 ? null : l10n.pinInvalid,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
