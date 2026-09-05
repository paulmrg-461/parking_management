import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/domain/commands/create_user_command.dart';
import '../../auth/domain/entities/user.dart';
import '../application/users_cubit.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  @override
  void initState() {
    super.initState();
    context.read<UsersCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<UsersCubit, UsersState>(
        builder: (context, state) {
          return switch (state) {
            UsersInitial() => const SizedBox.shrink(),
            UsersLoading() => const Center(child: CircularProgressIndicator()),
            UsersFailure(message: final message) => Center(child: Text(message)),
            UsersLoaded(users: final users) => ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _UserTile(user: users[index]),
              ),
          };
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _CreateUserDialog(),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(user.displayName),
      subtitle: Text('${user.username} · ${user.role.name}'),
      trailing: Switch(
        value: user.isActive,
        onChanged: (_) => context.read<UsersCubit>().toggleActive(user),
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _pinController = TextEditingController();
  UserRole _role = UserRole.operator;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final command = CreateUserCommand(
      username: _usernameController.text.trim(),
      displayName: _displayNameController.text.trim(),
      role: _role,
      pin: _pinController.text.trim(),
    );
    context.read<UsersCubit>().create(command);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New user'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            items: UserRole.values
                .map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _role = value ?? _role),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
