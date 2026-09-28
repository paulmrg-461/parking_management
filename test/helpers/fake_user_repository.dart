import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/users/domain/commands/create_user_command.dart';
import 'package:parking_management/features/users/domain/commands/update_user_command.dart';
import 'package:parking_management/features/users/domain/repositories/user_repository.dart';

/// User repository with no users; writes are not expected in app tests.
class EmptyUserRepository implements UserRepository {
  @override
  Future<List<User>> list() async => const [];

  @override
  Future<User> create(CreateUserCommand command) => throw UnimplementedError();

  @override
  Future<User> update(UpdateUserCommand command) => throw UnimplementedError();
}

/// In-memory users with recorded writes for page tests.
class FakeUserRepository implements UserRepository {
  FakeUserRepository(List<User> users) : users = List.of(users);

  List<User> users;
  final List<UpdateUserCommand> updates = [];
  CreateUserCommand? created;

  @override
  Future<List<User>> list() async => List.of(users);

  @override
  Future<User> create(CreateUserCommand command) async {
    created = command;
    final user = User(
      id: users.length + 10,
      username: command.username,
      displayName: command.displayName,
      role: command.role,
    );
    users.add(user);
    return user;
  }

  @override
  Future<User> update(UpdateUserCommand command) async {
    updates.add(command);
    users = [
      for (final u in users)
        u.id == command.id
            ? User(
                id: u.id,
                username: u.username,
                displayName: u.displayName,
                role: u.role,
                isActive: command.isActive ?? u.isActive,
              )
            : u,
    ];
    return users.firstWhere((u) => u.id == command.id);
  }
}
