import '../entities/user.dart';

class UpdateUserCommand {
  const UpdateUserCommand({
    required this.id,
    this.displayName,
    this.role,
    this.isActive,
  });

  final int id;
  final String? displayName;
  final UserRole? role;
  final bool? isActive;
}
