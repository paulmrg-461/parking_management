import 'package:equatable/equatable.dart';

enum UserRole { admin, operator }

class User extends Equatable {
  const User({
    this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.isActive = true,
  });

  final int? id;
  final String username;
  final String displayName;
  final UserRole role;
  final bool isActive;

  @override
  List<Object?> get props => [id, username, displayName, role, isActive];
}
