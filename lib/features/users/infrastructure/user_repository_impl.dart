import '../../auth/domain/entities/user.dart';
import '../domain/commands/create_user_command.dart';
import '../domain/commands/update_user_command.dart';
import '../domain/repositories/user_repository.dart';
import 'user_remote_data_source.dart';

/// Online-only on purpose: user management is an admin task and must never
/// be applied optimistically offline.
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._remote);

  final UserRemoteDataSource _remote;

  @override
  Future<List<User>> list() => _remote.list();

  @override
  Future<User> create(CreateUserCommand command) =>
      _remote.create(_toCreatePayload(command));

  @override
  Future<User> update(UpdateUserCommand command) =>
      _remote.update(command.id, _toUpdatePayload(command));

  Map<String, dynamic> _toCreatePayload(CreateUserCommand command) => {
    'username': command.username,
    'display_name': command.displayName,
    'role': command.role.name,
    'pin': command.pin,
  };

  Map<String, dynamic> _toUpdatePayload(UpdateUserCommand command) => {
    if (command.displayName != null) 'display_name': command.displayName,
    if (command.role != null) 'role': command.role!.name,
    if (command.isActive != null) 'is_active': command.isActive,
  };
}
