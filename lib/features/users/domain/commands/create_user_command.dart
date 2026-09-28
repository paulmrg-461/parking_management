import '../../../auth/domain/entities/user.dart';

class CreateUserCommand {
  const CreateUserCommand({
    required this.username,
    required this.displayName,
    required this.role,
    required this.pin,
  });

  final String username;
  final String displayName;
  final UserRole role;
  final String pin;
}
