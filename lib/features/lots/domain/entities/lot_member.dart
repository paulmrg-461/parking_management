import 'package:equatable/equatable.dart';

class LotMember extends Equatable {
  const LotMember({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    this.isActive = true,
  });

  final int userId;
  final String username;
  final String displayName;
  final String role;
  final bool isActive;

  bool get isAdmin => role == 'admin';

  factory LotMember.fromJson(Map<String, dynamic> json) => LotMember(
    userId: (json['user_id'] as num).toInt(),
    username: json['username'] as String? ?? '',
    displayName: json['display_name'] as String? ?? '',
    role: json['role'] as String? ?? 'operator',
    isActive: json['is_active'] as bool? ?? true,
  );

  @override
  List<Object?> get props => [userId, username, displayName, role, isActive];
}
