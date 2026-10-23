import '../../../auth/domain/entities/user.dart';

class CreateUserCommand {
  const CreateUserCommand({
    required this.username,
    required this.displayName,
    required this.role,
    required this.pin,
    this.lotId,
  });

  final String username;
  final String displayName;
  final UserRole role;
  final String pin;

  /// Site the user starts in. `null` lets the server use the default lot.
  final int? lotId;
}
