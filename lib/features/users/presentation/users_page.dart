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
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_chip.dart';
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
  String _query = '';

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
              query: _query,
              onFilter: (filter) => setState(() => _filter = filter),
              onQuery: (query) => setState(() => _query = query),
              onReset: () => setState(() {
                _filter = _RoleFilter.all;
                _query = '';
              }),
              onAdd: () => _addUser(context, context.read<UsersCubit>()),
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
          context.l10n.usersEmptyHint,
          title: context.l10n.usersEmptyTitle,
          icon: Icons.people_outline,
          action: FilledButton.icon(
            onPressed: () => _addUser(context, context.read<UsersCubit>()),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.usersAddFirst),
          ),
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
    required this.query,
    required this.onFilter,
    required this.onQuery,
    required this.onReset,
    required this.onAdd,
  });

  final List<User> users;
  final _RoleFilter filter;
  final String query;
  final ValueChanged<_RoleFilter> onFilter;
  final ValueChanged<String> onQuery;
  final VoidCallback onReset;
  final VoidCallback onAdd;

  List<User> get _visible {
    final needle = query.trim().toLowerCase();
    return [
      for (final user in users)
        if (switch (filter) {
              _RoleFilter.all => true,
              _RoleFilter.admin => user.role == UserRole.admin,
              _RoleFilter.operator => user.role == UserRole.operator,
            } &&
            (needle.isEmpty ||
                user.displayName.toLowerCase().contains(needle) ||
                user.username.toLowerCase().contains(needle)))
          user,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: FilterBar(
            summary: l10n.recordsCount(visible.length),
            onClear: filter == _RoleFilter.all && query.isEmpty
                ? null
                : onReset,
            clearLabel: l10n.actionClearFilters,
            children: [
              SizedBox(
                width: 260,
                child: SearchField(
                  label: l10n.usersSearchLabel,
                  hint: l10n.usersSearchHint,
                  textCapitalization: TextCapitalization.words,
                  onChanged: onQuery,
                ),
              ),
              SegmentedButton<_RoleFilter>(
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
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? EmptyState(
                  message: l10n.usersFilterEmpty,
                  icon: Icons.filter_alt_off_outlined,
                  action: FilledButton.tonalIcon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.usersAddFirst),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: Space.xxl * 2),
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

  String get _initials {
    final name = user.displayName.trim();
    if (name.isEmpty) {
      return user.username.characters.first.toUpperCase();
    }
    final parts = name.split(RegExp(r'\s+'));
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final admin = user.role == UserRole.admin;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: admin
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        foregroundColor: admin
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        child: Text(
          _initials,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(user.displayName)),
          const SizedBox(width: Space.sm),
          StatusChip(
            label: user.role.label(l10n),
            tone: admin ? StatusTone.pending : StatusTone.neutral,
          ),
        ],
      ),
      subtitle: Text('@${user.username}'),
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
