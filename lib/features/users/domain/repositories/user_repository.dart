import '../../../auth/domain/entities/user.dart';
import '../commands/create_user_command.dart';
import '../commands/update_user_command.dart';

/// Admin user management port (the signed-in session stays in `auth`).
abstract class UserRepository {
  Future<List<User>> list();

  Future<User> create(CreateUserCommand command);

  Future<User> update(UpdateUserCommand command);
}
